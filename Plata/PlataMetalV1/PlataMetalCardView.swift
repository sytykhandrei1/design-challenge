import SwiftUI
import RealityKit
import ImageIO
import OSLog

/// Two finishes share PBR maps and ID-1 geometry; the front uses the requested SANTIAGO D FERNANDEZ engraving.
/// The Obsidiana coating is a standard material treatment, not a repainted texture.
enum PlataMetalFinish: String, CaseIterable, Identifiable {
    case plata, obsidiana
    var id: String { rawValue }
    var title: String { self == .plata ? "Plata" : "Obsidiana" }
    var subtitle: String {
        self == .plata ? "Plata—polished silver, catches the light"
            : "Obsidiana—matte PVD, dark to the edge"
    }
    var surfaceTint: UIColor { self == .plata ? .white : UIColor(white: 0.42, alpha: 1) }
    // The supplied silver maps average 0.29; the coating increases this to about 0.61.
    var roughnessScale: Float { self == .plata ? 1 : 2.1 }
    var edgeTint: UIColor {
        self == .plata ? UIColor(red: 0.53, green: 0.54, blue: 0.55, alpha: 1)
            : UIColor(white: 0.28, alpha: 1)
    }
    var edgeRoughness: Float { self == .plata ? 0.24 : 0.62 }
}

/// Non-AR RealityKit card. One finger rotates X/Y; pinch magnifies; double tap resets zoom.
struct PlataMetalCardView: UIViewRepresentable {
    var pose: PlataMetalV1Pose = .frontGrazing
    var resourceBundle: Bundle = .main
    var poseRevision: Int = 0
    var finish: PlataMetalFinish = .plata

    @MainActor
    static func prewarmGalleryResources() async throws {
        _ = try await PlataMetalGalleryResources.shared.load(bundle: .main)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlataMetalV1SceneView {
        let view = PlataMetalV1SceneView(frame: .zero, cameraMode: .nonAR,
                                        automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(white: 0.045, alpha: 1))
        view.renderOptions.insert(.disableMotionBlur)
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "plata-metal-v1-scene"
        view.accessibilityLabel = "PLATA Metal, interactive 3D card"
        view.accessibilityHint = "Drag to rotate. Pinch to magnify. Double tap to reset zoom."
        context.coordinator.start(view: view, bundle: resourceBundle, pose: pose, finish: finish)
        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                        action: #selector(Coordinator.didPan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                            action: #selector(Coordinator.didPinch(_:)))
        view.addGestureRecognizer(pinch)
        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.resetZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        return view
    }

    func updateUIView(_ uiView: PlataMetalV1SceneView, context: Context) {
        context.coordinator.setPose(pose, revision: poseRevision)
        context.coordinator.setFinish(finish)
    }

    static func dismantleUIView(_ uiView: PlataMetalV1SceneView, coordinator: Coordinator) {
        coordinator.task?.cancel()
        uiView.scene.anchors.removeAll()
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var card: Entity?
        weak var view: PlataMetalV1SceneView?
        var task: Task<Void, Never>?
        private var selectedPose: PlataMetalV1Pose?
        private var selectedRevision = 0
        private var selectedFinish: PlataMetalFinish = .plata
        private var pinchStartZoom: Float = 1
        private var yaw: Float = 0
        private var pitch: Float = 0

        func start(view: PlataMetalV1SceneView, bundle: Bundle, pose: PlataMetalV1Pose, finish: PlataMetalFinish,
                   usesGalleryResourceCache: Bool = false) {
            self.view = view
            selectedFinish = finish
            setPose(pose)
            view.showStatus("Loading PLATA Metal…")
            task = Task { @MainActor [weak self, weak view] in
                guard let self, let view else { return }
                do {
                    let resources = PlataMetalV1Resources(bundle: bundle)
                    // Validate the complete inventory first, including the exact missing filename.
                    try resources.validate()
                    let card: Entity
                    let environment: EnvironmentResource
                    if usesGalleryResourceCache {
                        let prepared = try await PlataMetalGalleryResources.shared.load(bundle: bundle)
                        card = prepared.prototype.clone(recursive: true)
                        environment = prepared.environment
                    } else {
                        // Standalone/Transfer demo keeps its original lifecycle.
                        card = try await PlataMetalV1Factory.makeCard(resources: resources)
                        environment = try await resources.environment()
                    }
                    try Task.checkCancellation()
                    let root = AnchorEntity(world: .zero)
                    root.addChild(card)
                    self.card = card
                    self.applyFinish()
                    self.applyRotation()
                    view.environment.lighting.resource = environment
                    view.environment.lighting.intensityExponent = -0.7
                    view.studioCamera.camera = .init(near: 0.001, far: 10, fieldOfViewInDegrees: 34)
                    root.addChild(view.studioCamera)
                    let key = DirectionalLight()
                    key.light.intensity = 300
                    key.orientation = simd_quatf(angle: -0.7, axis: [1, 0, 0]) *
                        simd_quatf(angle: 0.7, axis: [0, 1, 0])
                    root.addChild(key)
                    let fill = DirectionalLight()
                    fill.light.intensity = 80
                    fill.light.color = UIColor(white: 0.78, alpha: 1)
                    fill.orientation = simd_quatf(angle: 0.55, axis: [1, 0, 0]) *
                        simd_quatf(angle: -1.15, axis: [0, 1, 0])
                    root.addChild(fill)
                    view.scene.addAnchor(root)
                    view.setNeedsLayout()
                    view.showStatus(nil)
                    self.applyRotation()
                    PlataMetalV1Resources.logger.info("Ready: 12 PBR textures + plata_studio.hdr; OpenGL; non-AR")
                } catch is CancellationError {
                    // The SwiftUI view was removed; no scene should be installed after teardown.
                } catch {
                    guard !Task.isCancelled else { return }
                    let message = "PLATA Metal: \(error.localizedDescription)"
                    PlataMetalV1Resources.logger.error("\(message, privacy: .public)")
                    view.showStatus(message)
                }
            }
        }

        func setPose(_ pose: PlataMetalV1Pose, revision: Int = 0) {
            guard selectedPose != pose || selectedRevision != revision else { return }
            selectedRevision = revision
            selectedPose = pose
            yaw = pose.yaw
            pitch = pose.pitch
            view?.zoomFactor = 1
            applyRotation()
        }

        func setFinish(_ finish: PlataMetalFinish) {
            guard selectedFinish != finish else { return }
            selectedFinish = finish
            applyFinish()
            applyRotation()
        }

        private func applyFinish() {
            guard let card else { return }
            card.name = "PLATA Metal — \(selectedFinish.title)"
            for name in ["Front surface", "Back surface"] {
                guard let surface = card.findEntity(named: name) as? ModelEntity,
                      var model = surface.model,
                      var material = model.materials.first as? PhysicallyBasedMaterial else {
                    assertionFailure("PLATA Metal: missing PBR surface \(name)")
                    continue
                }
                material.baseColor.tint = selectedFinish.surfaceTint
                material.roughness.scale = selectedFinish.roughnessScale
                model.materials = [material]
                surface.model = model
            }
            if let edge = card.findEntity(named: "Metal body and edge") as? ModelEntity,
               var model = edge.model,
               var material = model.materials.first as? PhysicallyBasedMaterial {
                material.baseColor.tint = selectedFinish.edgeTint
                material.roughness = .init(scale: selectedFinish.edgeRoughness)
                model.materials = [material]
                edge.model = model
            }
            // Chip remains a separate, silver contact insert on both finishes.
            view?.accessibilityLabel = "PLATA Metal, \(selectedFinish.title), interactive 3D card"
            PlataMetalV1Resources.logger.info("Finish: \(self.selectedFinish.rawValue, privacy: .public), roughness scale \(self.selectedFinish.roughnessScale)")
        }

        private func applyRotation() {
            card?.orientation = simd_quatf(angle: pitch, axis: [1, 0, 0]) *
                simd_quatf(angle: yaw, axis: [0, 1, 0])
            if card != nil {
                let zoom = String(format: "%.2f", view?.zoomFactor ?? 1)
                view?.accessibilityValue = "Ready; yaw \(Int(yaw * 180 / .pi)); pitch \(Int(pitch * 180 / .pi)); zoom \(zoom); finish \(selectedFinish.rawValue)"
            }
        }

        @objc func didPinch(_ recognizer: UIPinchGestureRecognizer) {
            guard card != nil, let view else { return }
            if recognizer.state == .began { pinchStartZoom = view.zoomFactor }
            if recognizer.state == .began || recognizer.state == .changed {
                view.zoomFactor = min(max(pinchStartZoom * Float(recognizer.scale), 1), 3)
                view.layoutIfNeeded()
                applyRotation()
            }
        }

        @objc func resetZoom(_ recognizer: UITapGestureRecognizer) {
            guard card != nil else { return }
            view?.zoomFactor = 1
            applyRotation()
        }

        @objc func didPan(_ recognizer: UIPanGestureRecognizer) {
            guard card != nil else { return }
            if recognizer.state == .changed {
                let delta = recognizer.translation(in: recognizer.view)
                yaw = (yaw + Float(delta.x) * 0.008).truncatingRemainder(dividingBy: 2 * .pi)
                pitch = min(max(pitch + Float(delta.y) * 0.006, -.pi / 2), .pi / 2)
                applyRotation()
            }
            recognizer.setTranslation(.zero, in: recognizer.view)
        }
    }
}

/// Fits the card's bounding sphere, so every orientation stays inside the viewport.
final class PlataMetalV1SceneView: ARView {
    let studioCamera = PerspectiveCamera()
    private let statusLabel = UILabel()
    var zoomFactor: Float = 1 { didSet { setNeedsLayout() } }
    /// Embedded galleries supply their own camera matched to their artwork slot.
    var fitsCardAutomatically = true

    override func layoutSubviews() {
        super.layoutSubviews()
        statusLabel.frame = bounds.insetBy(dx: 24, dy: 24)
        guard fitsCardAutomatically else { return }
        guard bounds.width > 0, bounds.height > 0 else { return }
        let aspect = Float(bounds.width / bounds.height)
        let halfVerticalFOV: Float = 34 * .pi / 360
        let halfHorizontalFOV = atan(tan(halfVerticalFOV) * aspect)
        let radius = simd_length(SIMD3<Float>(PlataMetalV1Geometry.width,
                                             PlataMetalV1Geometry.height,
                                             PlataMetalV1Geometry.thickness)) / 2
        let fitDistance = radius / sin(min(halfVerticalFOV, halfHorizontalFOV)) * 1.10
        // Move the camera rather than scaling the physical object. Never cross its bounding sphere.
        studioCamera.position = [0, 0, max(fitDistance / zoomFactor, radius + 0.008)]
    }

    func showStatus(_ message: String?) {
        if statusLabel.superview == nil {
            statusLabel.numberOfLines = 0
            statusLabel.textColor = .white
            statusLabel.font = .preferredFont(forTextStyle: .footnote)
            statusLabel.textAlignment = .center
            addSubview(statusLabel)
        }
        statusLabel.text = message
        statusLabel.isHidden = message == nil
        accessibilityValue = message ?? "Ready"
        setNeedsLayout()
    }
}

enum PlataMetalV1Pose: String, CaseIterable {
    case front, frontGrazing, back, edge
    var yaw: Float {
        switch self {
        case .front: 0
        case .frontGrazing: 0.30
        case .back: .pi + 0.30
        case .edge: .pi / 2 - 0.035
        }
    }
    var pitch: Float { self == .front ? 0 : -0.16 }
}

private struct PlataMetalV1ResourceError: LocalizedError {
    let filename: String
    let reason: String
    var errorDescription: String? { "plata_metal_v1/\(filename): \(reason)" }
}

@MainActor
private struct PlataMetalV1Resources {
    static let logger = Logger(subsystem: "com.sytykhandrei.platacards", category: "PlataMetalV1")
    let bundle: Bundle
    // All three normal maps deliberately use the same convention.
    static let normalConvention = "opengl"
    static let filenames = ["front_alex_smith", "back", "chip"].flatMap { side in
        ["\(side)_basecolor\(side == "chip" ? "_rgba" : "").png",
         "\(side)_roughness_rgb.png", "\(side)_metalness_rgb.png",
         "\(side)_normal_\(normalConvention).png"]
    } + ["plata_studio.hdr"]

    func url(_ filename: String) throws -> URL {
        guard let url = bundle.url(forResource: filename, withExtension: nil,
                                   subdirectory: "plata_metal_v1") else {
            throw PlataMetalV1ResourceError(filename: filename, reason: "missing from app bundle")
        }
        return url
    }

    func validate() throws { for filename in Self.filenames { _ = try url(filename) } }

    func texture(_ filename: String, semantic: TextureResource.Semantic) async throws -> TextureResource {
        let source = try url(filename)
        do {
            let texture = try await TextureResource(contentsOf: source,
                withName: "plata_metal_v1/\(filename)",
                options: .init(semantic: semantic, compression: .none))
            Self.logger.info("Loaded \(filename, privacy: .public): \(texture.width)x\(texture.height)")
            return texture
        } catch {
            throw PlataMetalV1ResourceError(filename: filename, reason: error.localizedDescription)
        }
    }

    func material(side originalSide: String) async throws -> PhysicallyBasedMaterial {
        let side = originalSide == "front" ? "front_alex_smith" : originalSide
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .white, texture: .init(try await texture(
            "\(side)_basecolor\(side == "chip" ? "_rgba" : "").png", semantic: .color)))
        material.roughness = .init(scale: 1, texture: .init(try await texture("\(side)_roughness_rgb.png", semantic: .raw)))
        material.metallic = .init(scale: 1, texture: .init(try await texture("\(side)_metalness_rgb.png", semantic: .raw)))
        material.normal.texture = .init(try await texture("\(side)_normal_\(Self.normalConvention).png", semantic: .normal))
        return material
    }

    func environment() async throws -> EnvironmentResource {
        let filename = "plata_studio.hdr"
        let source = try url(filename)
        // Decode the raw Radiance HDR directly. No skybox asset compilation or LDR conversion.
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0,
                  [kCGImageSourceShouldAllowFloat: true] as CFDictionary) else {
            throw PlataMetalV1ResourceError(filename: filename, reason: "cannot decode Radiance HDR")
        }
        do {
            let environment = try await EnvironmentResource(equirectangular: image,
                                                             withName: "plata_metal_v1/studio")
            Self.logger.info("Loaded plata_studio.hdr: \(image.width)x\(image.height), \(image.bitsPerComponent)-bit components")
            return environment
        } catch {
            throw PlataMetalV1ResourceError(filename: filename, reason: error.localizedDescription)
        }
    }
}

@MainActor
private enum PlataMetalV1Factory {
    static func makeCard(resources: PlataMetalV1Resources) async throws -> Entity {
        let card = Entity()
        card.name = "PLATA Metal — Plata"
        var edgeMaterial = PhysicallyBasedMaterial()
        edgeMaterial.baseColor.tint = UIColor(red: 0.53, green: 0.54, blue: 0.55, alpha: 1)
        edgeMaterial.roughness = 0.24
        edgeMaterial.metallic = 1.0
        let edge = ModelEntity(mesh: try PlataMetalV1Geometry.edge(), materials: [edgeMaterial])
        edge.name = "Metal body and edge"
        card.addChild(edge)

        let surface = try PlataMetalV1Geometry.surface()
        let front = ModelEntity(mesh: surface, materials: [try await resources.material(side: "front")])
        front.name = "Front surface"
        front.position.z = PlataMetalV1Geometry.thickness / 2
        card.addChild(front)

        let back = ModelEntity(mesh: surface, materials: [try await resources.material(side: "back")])
        back.name = "Back surface"
        back.position.z = -PlataMetalV1Geometry.thickness / 2
        // Rotate the whole local surface, including its UVs and tangent basis. No negative scale.
        back.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
        card.addChild(back)

        let chipWidth = PlataMetalV1Geometry.width * 338 / 2048
        let chipHeight = PlataMetalV1Geometry.height * 240 / 1292
        let chip = ModelEntity(mesh: try PlataMetalV1Geometry.surface(
            width: chipWidth, height: chipHeight, radius: 0.00155),
            materials: [try await resources.material(side: "chip")])
        chip.name = "Inserted chip"
        chip.position = [PlataMetalV1Geometry.width * (299 / 2048.0 - 0.5),
                         PlataMetalV1Geometry.height * (0.5 - 510 / 1292.0),
                         PlataMetalV1Geometry.thickness / 2 + 0.000004]
        // A real 40 µm insert, with 36 µm seated inside the card and only 4 µm proud.
        let chipEdge = ModelEntity(mesh: try PlataMetalV1Geometry.edge(width: chipWidth,
            height: chipHeight, radius: 0.00155, thickness: 0.000040), materials: [edgeMaterial])
        chipEdge.position.z = -0.000020
        chip.addChild(chipEdge)
        card.addChild(chip)
        return card
    }
}

/// Main-gallery-only warm resources. A prototype is never attached to a scene;
/// each destination gets independent entities sharing immutable meshes/textures.
@MainActor
private final class PlataMetalGalleryResources {
    struct Prepared {
        let prototype: Entity
        let environment: EnvironmentResource
    }
    static let shared = PlataMetalGalleryResources()
    private var task: Task<Prepared, Error>?
    private var bundleURL: URL?
    private var revision = UUID()
    private var memoryObserver: NSObjectProtocol?

    private init() {
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.revision = UUID()
                self?.task?.cancel()
                self?.task = nil
            }
        }
    }

    func load(bundle: Bundle) async throws -> Prepared {
        if let task, bundleURL == bundle.bundleURL { return try await task.value }
        task?.cancel()
        bundleURL = bundle.bundleURL
        let request = UUID()
        revision = request
        let loading = Task { @MainActor in
            let resources = PlataMetalV1Resources(bundle: bundle)
            try resources.validate()
            let prototype = try await PlataMetalV1Factory.makeCard(resources: resources)
            try Task.checkCancellation()
            // The main Digital/Metal adapters use this exact same raw HDR.
            // Share its resource and off-main decode without changing lighting.
            let environment = try await PlataDigitalCardMaterial.environment(bundle: bundle)
            try Task.checkCancellation()
            return Prepared(prototype: prototype, environment: environment)
        }
        task = loading
        do { return try await loading.value }
        catch { if revision == request { task = nil }; throw error }
    }
}

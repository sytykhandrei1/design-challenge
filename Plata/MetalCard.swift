import SwiftUI
import UIKit
import SceneKit
import MetalKit
import RealityKit
import simd

@MainActor
enum CardGalleryResources {
    static func prewarmPlastic() async throws {
        // Full-quality ready appearances share maps across matte finishes.
        // No throwaway card geometry or hidden ARView is created here.
        PlataPlasticCardMaterial.beginPrewarmingSession()
        _ = try await PlataPlasticCardMaterial.environment(bundle: .main)
        try await PlataPlasticCardMaterial.prewarm(finishes: CardCategory.plasticFinishes)
    }
}

struct MetalCard: View {
    var design: CardDesign = CardCatalog.all[0]
    var options = CardFaceOptions()
    var interactive: Bool
    var prepareForInteraction: Bool
    var quarterTurned = false
    var animatePreviewEntrance = false
    var onPreviewDrag: ((CardPreviewDragEvent) -> Void)? = nil
    var onPreviewZoomEnd: ((Double) -> Void)? = nil
    @State private var isVisible = true

    var body: some View {
        Group {
            if isVisible {
                CardSceneRenderer(design: design, options: options, interactive: interactive,
                                  prepareForInteraction: prepareForInteraction,
                                  quarterTurned: quarterTurned, animatePreviewEntrance: animatePreviewEntrance,
                                  onPreviewDrag: onPreviewDrag, onPreviewZoomEnd: onPreviewZoomEnd)
            } else {
                Color.clear
            }
        }
        // A pushed-off SwiftUI destination remains in memory. Release its real
        // renderer once the transition finishes, and rebuild it on native back.
        // Retaining the old Digital ARView can leave the next scene blank.
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

private struct CardSceneRenderer: UIViewRepresentable {
    var design: CardDesign = CardCatalog.all[0]
    var options = CardFaceOptions()
    var interactive: Bool
    var prepareForInteraction: Bool
    /// The gallery preview rotates the UIView by 90°. Setup keeps it horizontal.
    var quarterTurned = false
    var animatePreviewEntrance = false
    var onPreviewDrag: ((CardPreviewDragEvent) -> Void)? = nil
    /// Optional diagnostics: peak scale actually reached by a completed pinch.
    var onPreviewZoomEnd: ((Double) -> Void)? = nil

    func makeUIView(context: Context) -> MetalCardSurface { MetalCardSurface() }
    func updateUIView(_ view: MetalCardSurface, context: Context) {
        view.configure(design: design, options: options, quarterTurned: quarterTurned)
        view.onPreviewDrag = onPreviewDrag
        view.onPreviewZoomEnd = onPreviewZoomEnd
        view.prepareForInteraction = prepareForInteraction
        view.animatePreviewEntrance = animatePreviewEntrance
        view.interactive = interactive
    }
    static func dismantleUIView(_ uiView: MetalCardSurface, coordinator: ()) { uiView.releaseResources() }
}

enum CardPreviewDragEvent {
    case changed(CGFloat)
    case ended(CGFloat, cancelled: Bool)
}

/// A closed, bevelled metal solid. One finger controls yaw; two fingers combine
/// anchored zoom, pan and roll, then return the entire photo transform together.
final class MetalCardSurface: UIView, UIGestureRecognizerDelegate {
    private let restingFace = CALayer()
    private var sceneView: SCNView?
    // The interaction proxy stays in SceneKit. All collections render through
    // their original RealityKit geometry, materials and studio lighting.
    private var metalSceneView: PlataMetalV1SceneView?
    private var metalCoordinator: PlataMetalCardView.Coordinator?
    private var metalLoadTask: Task<Void, Never>?
    private var digitalSceneView: PlataMetalV1SceneView?
    private var digitalCoordinator: PlataDigitalCardView.Coordinator?
    private var digitalLoadTask: Task<Void, Never>?
    private var plasticSceneView: PlataMetalV1SceneView?
    private var plasticCoordinator: PlataPlasticCardView.Coordinator?
    private var plasticLoadTask: Task<Void, Never>?
    private let cardNode = SCNNode()
    private let cameraNode = SCNNode()
    private var rotation = CardPhysics()
    private var zoom = CardZoom()
    private var contact: CardContactGestureRecognizer!
    private var contactNeedsRebase = false
    private var twoFingerActive = false
    private var previewDrag = CardPreviewDrag()
    var onPreviewDrag: ((CardPreviewDragEvent) -> Void)?
    var onPreviewZoomEnd: ((Double) -> Void)?
    private var gesturePeakZoom: Double = 1
    private var twoFingerInitialDistance: CGFloat = 1
    private var twoFingerInitialAngle: CGFloat = 0
    private var zoomAnchorDepth: Float = 0
    private var returnWork: DispatchWorkItem?
    private var returnGeneration = 0
    private var animationLink: CADisplayLink?
    private var lastSize = CGSize.zero
    private var lastViewportSide: CGFloat = 0
    private var proxyGeometryHeight: CGFloat = 0
    private var proxyGeometries: [Int: SCNGeometry] = [:]
    private var galleryCameras = Set<ObjectIdentifier>()
    private var prepared = false
    private var configured = false
    private var design = CardCatalog.all[0]
    private var faceOptions = CardFaceOptions()
    private var quarterTurned = false
    private var frontImage: UIImage?
    private var backImage: UIImage?
    private var pbrGeneration = 0
    private var pbrLoading = Set<String>()
    private var pbrStandard = [String: SCNMaterial]()
    private var pbrZoom: (side: String, material: SCNMaterial)?
    private var pbrReady = false
    private var pbrDisplayedZoomSide: String?

    var prepareForInteraction = false {
        didSet {
            guard oldValue != prepareForInteraction else { return }
            if prepareForInteraction || design.usesRealityKit { prepareScene() }
            else if !interactive { discardScene() }
        }
    }
    var animatePreviewEntrance = false
    var interactive = false {
        didSet {
            guard oldValue != interactive else { return }
            contact.isEnabled = interactive
            if interactive {
                prepareScene()
                if quarterTurned && animatePreviewEntrance {
                    cancelReturnTimer()
                    rotation.beginPreviewEntrance(at: CACurrentMediaTime())
                    startAnimationLink()
                }
            }
            else {
                cancelReturnTimer()
                stopAnimationLink()
                rotation.reset()
                zoom.reset()
                renderOrientation()
            }
            updateVisibility()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        clipsToBounds = false
        restingFace.contents = frontImage?.cgImage
        restingFace.contentsGravity = .resize
        restingFace.masksToBounds = true
        layer.addSublayer(restingFace)
        contact = CardContactGestureRecognizer(target: self, action: #selector(handleContact(_:)))
        contact.isEnabled = false
        contact.delegate = self
        addGestureRecognizer(contact)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(design: CardDesign, options: CardFaceOptions, quarterTurned: Bool) {
        let textureChanged = !configured || self.design != design || faceOptions != options
        let basisChanged = self.quarterTurned != quarterTurned
        // SwiftUI moves the card's container on every drag tick. Its material,
        // camera and proxy scene do not change with that screen-space movement.
        guard textureChanged || basisChanged else { return }
        let artworkChanged = !configured || self.design.assetName != design.assetName || faceOptions != options
        configured = true
        self.design = design
        faceOptions = options
        self.quarterTurned = quarterTurned
        if textureChanged {
            if !design.usesRealityKit, artworkChanged {
                frontImage = CardTextureRenderer.front(named: design.assetName, options: options).preparingForDisplay()
                backImage = CardTextureRenderer.backPlaceholder(for: design, options: options).preparingForDisplay()
            } else if design.usesRealityKit {
                // RealityKit supplies both faces. Do not rasterize unused
                // placeholder bitmaps when its color crosses a midpoint.
                frontImage = nil
                backImage = nil
            }
            CATransaction.begin(); CATransaction.setDisableActions(true)
            restingFace.contents = frontImage?.cgImage
            CATransaction.commit()
            if design.usesBrushedPBR {
                pbrGeneration += 1
                pbrLoading.removeAll()
                pbrZoom = nil
                pbrDisplayedZoomSide = nil
                pbrStandard.removeAll()
                pbrReady = false
                requestPBRStandard()
            } else {
                pbrGeneration += 1
                pbrLoading.removeAll()
                pbrZoom = nil
                pbrDisplayedZoomSide = nil
                pbrStandard.removeAll()
                pbrReady = false
                if !design.usesRealityKit, artworkChanged {
                    cardNode.geometry?.materials = [faceMaterial(frontImage), faceMaterial(backImage, isBack: true), edgeMaterial()]
                }
            }
            updateVisibility()
            sceneView?.setNeedsDisplay()
        }
        if basisChanged { layoutScene(); renderOrientation() }
        if let finish = design.metalFinish {
            prepareScene()
            prepareMetalScene(finish: finish)
            metalCoordinator?.setFinish(finish)
            renderOrientation()
        }
        if let skin = design.digitalSkin {
            prepareScene()
            let configuration = PlataDigitalCardView(skin: skin, pose: .front)
            prepareDigitalScene(configuration: configuration)
            digitalCoordinator?.update(configuration)
            if textureChanged { synchronizeDigitalAppearance() }
            renderOrientation()
        }
        if let finish = design.plasticFinish {
            prepareScene()
            var details = PlataPlasticDetails()
            details.name = options.cardholderName
            details.showsName = options.showsCardholderName
            details.showsNumber = options.showsCardNumber
            let configuration = PlataPlasticCardView(skin: finish, details: details, pose: .front)
            preparePlasticScene(configuration: configuration)
            plasticCoordinator?.update(configuration)
            if textureChanged { synchronizePlasticAppearance() }
            renderOrientation()
        }
    }

    private func prepareScene() {
        guard sceneView == nil else { return }
        let view = SCNView(frame: .zero, options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 120
        view.rendersContinuously = false
        view.isPlaying = false
        let scene = SCNScene()
        scene.rootNode.addChildNode(cardNode)
        let camera = SCNCamera()
        camera.fieldOfView = 28
        camera.zNear = 0.1
        camera.zFar = 1500
        camera.wantsHDR = design.usesBrushedPBR
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode
        // Large, restrained studio fill keeps the supplied copper colour legible
        // while directional specular light moves over the actual rotated normals.
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor.white
        ambient.intensity = design.usesBrushedPBR ? 200 : 800
        let fill = SCNNode(); fill.light = ambient
        scene.rootNode.addChildNode(fill)
        addLight(to: scene, position: SCNVector3(-90, 110, 220), intensity: design.usesBrushedPBR ? 900 : 240)
        addLight(to: scene, position: SCNVector3(100, -80, -180), intensity: design.usesBrushedPBR ? 350 : 200)
        if design.usesBrushedPBR,
           let url = BrushedPBR.url("studio-environment.png") {
            scene.lightingEnvironment.contents = UIImage(contentsOfFile: url.path)
            scene.lightingEnvironment.intensity = 1.2
        } else {
            scene.lightingEnvironment.contents = UIColor(white: 0.7, alpha: 1)
            scene.lightingEnvironment.intensity = 0.7
        }
        view.scene = scene
        addSubview(view)
        sceneView = view
        layoutScene()
        updateVisibility()
    }

    private func addLight(to scene: SCNScene, position: SCNVector3, intensity: CGFloat) {
        let light = SCNLight()
        light.type = .directional
        light.color = UIColor(red: 1, green: 0.96, blue: 0.91, alpha: 1)
        light.intensity = intensity
        let node = SCNNode(); node.light = light; node.position = position
        node.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(node)
    }

    private func prepareMetalScene(finish: PlataMetalFinish) {
        guard metalSceneView == nil else { return }
        let view = PlataMetalV1SceneView(frame: .zero, cameraMode: .nonAR,
                                       automaticallyConfigureSession: false)
        view.fitsCardAutomatically = false
        view.environment.background = .color(.clear)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.renderOptions.insert(.disableMotionBlur)
        addSubview(view)
        metalSceneView = view
        let coordinator = PlataMetalCardView.Coordinator()
        metalCoordinator = coordinator
        coordinator.start(view: view, bundle: .main, pose: .front, finish: finish,
                          usesGalleryResourceCache: true)
        metalLoadTask = Task { @MainActor [weak self, weak view] in
            await coordinator.task?.value
            guard let self, let view, self.metalSceneView === view, !Task.isCancelled else { return }
            self.layoutScene()
            self.renderOrientation()
            self.updateVisibility()
        }
        layoutScene()
        updateVisibility()
    }

    private func prepareDigitalScene(configuration: PlataDigitalCardView) {
        guard digitalSceneView == nil else { return }
        let view = PlataMetalV1SceneView(frame: .zero, cameraMode: .nonAR,
                                       automaticallyConfigureSession: false)
        view.fitsCardAutomatically = false
        view.environment.background = .color(.clear)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.renderOptions.insert(.disableMotionBlur)
        addSubview(view)
        digitalSceneView = view
        let coordinator = PlataDigitalCardView.Coordinator()
        digitalCoordinator = coordinator
        coordinator.start(view, configuration: configuration)
        synchronizeDigitalAppearance()
        layoutScene()
        updateVisibility()
    }

    private func synchronizeDigitalAppearance() {
        guard let coordinator = digitalCoordinator, let view = digitalSceneView else { return }
        digitalLoadTask?.cancel()
        digitalLoadTask = Task { @MainActor [weak self, weak view] in
            await coordinator.buildTask?.value
            await coordinator.appearanceTask?.value
            guard let self, let view, self.digitalSceneView === view, !Task.isCancelled else { return }
            view.layoutIfNeeded()
            self.layoutScene()
            self.renderOrientation()
            self.updateVisibility()
        }
    }

    private func preparePlasticScene(configuration: PlataPlasticCardView) {
        guard plasticSceneView == nil else { return }
        let view = PlataMetalV1SceneView(frame: .zero, cameraMode: .nonAR,
                                       automaticallyConfigureSession: false)
        view.fitsCardAutomatically = false
        view.environment.background = .color(.clear)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.renderOptions.insert(.disableMotionBlur)
        addSubview(view)
        plasticSceneView = view
        let coordinator = PlataPlasticCardView.Coordinator()
        plasticCoordinator = coordinator
        coordinator.start(view, configuration: configuration)
        synchronizePlasticAppearance()
        layoutScene()
        updateVisibility()
    }

    private func synchronizePlasticAppearance() {
        guard let coordinator = plasticCoordinator, let view = plasticSceneView else { return }
        plasticLoadTask?.cancel()
        plasticLoadTask = Task { @MainActor [weak self, weak view] in
            await coordinator.buildTask?.value
            await coordinator.appearanceTask?.value
            await coordinator.detailsTask?.value
            guard let self, let view, self.plasticSceneView === view, !Task.isCancelled else { return }
            view.layoutIfNeeded()
            self.layoutScene()
            self.renderOrientation()
            self.updateVisibility()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        restingFace.frame = bounds
        restingFace.cornerRadius = bounds.height * 0.10
        CATransaction.commit()
        layoutScene()
    }

    private func layoutScene() {
        guard let view = sceneView, bounds.width > 0, bounds.height > 0 else { return }
        // A square viewport accommodates every rotation, including the long edge
        // passing through a vertical pose; only the screen clips the result.
        // Enlarging the entity inside the old card-sized render target clipped
        // its pixels BEFORE the system could sample them for scroll edges.
        // Preview's render target covers the whole window diagonal; the camera
        // is recalibrated so the physical card's on-screen size does not change.
        let cardSide = hypot(bounds.width, bounds.height) * 1.08
        let windowSize = window?.bounds.size ?? .zero
        let side = quarterTurned
            ? max(cardSide, hypot(windowSize.width, windowSize.height) * 1.04)
            : cardSide
        let target = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        if view.frame != target { view.frame = target }
        for surface in [metalSceneView, digitalSceneView, plasticSceneView].compactMap({ $0 }) {
            if surface.frame != target { surface.frame = target }
        }
        guard lastSize != bounds.size || lastViewportSide != side else { return }
        lastSize = bounds.size
        lastViewportSide = side
        let modelWidth: CGFloat = 100
        let modelHeight = modelWidth * bounds.height / bounds.width
        let halfFrustum = side / bounds.width * modelWidth / 2
        cameraNode.position = SCNVector3(0, 0, Float(halfFrustum / tan(14 * .pi / 180)) + 0.45)
        if design.usesRealityKit {
            // This exact rounded mesh is only a CPU hit-test proxy, never the
            // rendered card. Reuse it when resizing; don't allocate face shaders
            // or rebuild its vertices during the preview animation.
            if cardNode.geometry == nil || abs(proxyGeometryHeight - modelHeight) > 0.0001 {
                let key = Int((modelHeight * 10000).rounded())
                if let cached = proxyGeometries[key] {
                    cardNode.geometry = cached
                } else {
                    let mesh = CardSolid.geometry(width: modelWidth, height: modelHeight, depth: 0.9, materials: [])
                    cardNode.geometry = mesh
                    // Gallery and preview are the two usual aspect ratios.
                    if proxyGeometries.count < 2 { proxyGeometries[key] = mesh }
                }
                proxyGeometryHeight = modelHeight
            }
        } else {
            let initialMaterials = [pbrStandard["front"] ?? faceMaterial(frontImage),
                                    pbrStandard["back"] ?? faceMaterial(backImage, isBack: true),
                                    pbrStandard["edge"] ?? edgeMaterial()]
            cardNode.geometry = design.usesBrushedPBR
                ? CardSolid.brushedGeometry(width: modelWidth, height: modelHeight, depth: 0.9, materials: initialMaterials)
                : CardSolid.geometry(width: modelWidth, height: modelHeight, depth: 0.9, materials: initialMaterials)
        }
        if design.usesBrushedPBR { requestPBRStandard() }
        renderOrientation()
        if design.usesRealityKit {
            // The hidden SceneKit geometry is only a hit-test/coordinate proxy;
            // preparing its shaders/textures on the GPU cannot improve the card.
            prepared = true
        } else if !prepared {
            // Prepare only after the selected card has nonzero geometry.
            view.prepare([cardNode]) { [weak self, weak view] success in
                DispatchQueue.main.async {
                    guard let self, let view, self.sceneView === view else { return }
                    self.prepared = success
                    self.updateVisibility()
                }
            }
        }
    }

    private func faceMaterial(_ image: UIImage?, isBack: Bool = false) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = image
        material.isDoubleSided = false
        material.diffuse.mipFilter = .linear
        // Baked engraving/brush detail stays in the base texture. A restrained
        // studio reflection is computed from the real view-space surface normal
        // and view vector, rather than a gradient following the finger.
        let stripeMask = isBack ? "((_surface.diffuseTexcoord.y > 0.095 && _surface.diffuseTexcoord.y < 0.285) ? 0.06 : 1.0)" : "1.0"
        material.shaderModifiers = [.fragment: """
        float3 n = normalize(_surface.normal);
        float3 v = normalize(-_surface.position);
        float3 r = reflect(-v, n);
        float3 key = normalize(float3(-0.35, 0.65, 1.0));
        float facing = clamp(dot(n, v), 0.0, 1.0);
        float band = pow(max(dot(r, key), 0.0), 22.0);
        float grazing = pow(1.0 - facing, 4.0);
        float coating = \(stripeMask);
        float illumination = 0.94 + 0.06 * max(dot(n, key), 0.0);
        float sheen = (band * 0.13 + grazing * 0.07) * coating;
        _output.color.rgb = _output.color.rgb * illumination + float3(1.0, 0.85, 0.67) * sheen;
        """]
        return material
    }

    private func edgeMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(red: 0.58, green: 0.34, blue: 0.19, alpha: 1)
        material.metalness.contents = 0.75
        material.roughness.contents = 0.45
        material.isDoubleSided = false
        return material
    }

    private func updateVisibility() {
        plasticSceneView?.isHidden = design.plasticFinish == nil
        digitalSceneView?.isHidden = design.digitalSkin == nil
        metalSceneView?.isHidden = design.metalFinish == nil
        if design.usesRealityKit {
            restingFace.isHidden = true
            sceneView?.isHidden = true
            return
        }
        let showSolid = interactive && prepared && (!design.usesBrushedPBR || pbrReady)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        restingFace.isHidden = showSolid
        CATransaction.commit()
        sceneView?.isHidden = !showSolid
        if showSolid { sceneView?.setNeedsDisplay() }
    }

    @objc private func handleContact(_ gesture: CardContactGestureRecognizer) {
        let time = CACurrentMediaTime()
        switch gesture.state {
        case .began:
            beginSingleFinger(gesture, at: time)
        case .changed:
            if gesture.activeTouchCount >= 2 {
                if !twoFingerActive { beginTwoFinger(gesture, at: time) }
                updateTwoFinger(gesture)
            } else if gesture.activeTouchCount == 1 {
                if twoFingerActive {
                    // A pinch usually ends one finger at a time. Keep treating
                    // the contact as the same two-finger gesture until the last
                    // finger lifts; otherwise the remaining finger can rebase as
                    // a one-finger drag and cancel the return to the upright pose.
                    contactNeedsRebase = true
                    return
                }
                if contactNeedsRebase || !rotation.isDragging {
                    beginSingleFinger(gesture, at: time)
                } else {
                    updateSingleFinger(gesture)
                }
            }
        case .ended:
            if twoFingerActive {
                finishTwoFinger(at: time)
            } else {
                let coasts = quarterTurned && previewDrag.direction == .rotate
                finishPreviewDrag(cancelled: false)
                if coasts {
                    if UIAccessibility.isReduceMotionEnabled {
                        rotation.returnToDefault(at: time, duration: 0.3)
                    } else {
                        rotation.endWithInertia(at: time)
                    }
                    startAnimationLink()
                } else {
                    rotation.end(at: time, scheduleReturn: !quarterTurned)
                    if !quarterTurned { armReturnTimer() }
                }
            }
        case .cancelled, .failed:
            if twoFingerActive {
                finishTwoFinger(at: time)
            } else {
                finishPreviewDrag(cancelled: true)
                rotation.end(at: time, scheduleReturn: interactive)
                if interactive { armReturnTimer() }
            }
        default: break
        }
    }

    private func beginSingleFinger(_ gesture: CardContactGestureRecognizer, at time: Double) {
        guard gesture.activeTouchCount == 1 else { return }
        cancelReturnTimer()
        let p = gesture.latestLocation(in: window)
        previewDrag.begin(x: p.x, y: p.y)
        let screenBounds = convert(bounds, to: window)
        rotation.begin(x: p.x, y: p.y, width: max(screenBounds.width, 1),
                       height: max(screenBounds.height, 1), at: time,
                       response: quarterTurned ? CardPhysics.previewDragResponse : 1)
        contactNeedsRebase = false
    }

    private func updateSingleFinger(_ gesture: CardContactGestureRecognizer) {
        let p = gesture.latestLocation(in: window)
        if onPreviewDrag != nil {
            previewDrag.update(x: p.x, y: p.y)
            if previewDrag.direction == .dismiss {
                onPreviewDrag?(.changed(previewDrag.translation))
                return
            }
            guard previewDrag.direction == .rotate else { return }
        }
        rotation.update(x: p.x, y: p.y, at: CACurrentMediaTime())
        renderOrientation()
    }

    private func finishPreviewDrag(cancelled: Bool) {
        if previewDrag.direction == .dismiss {
            onPreviewDrag?(.ended(previewDrag.translation, cancelled: cancelled))
        }
        previewDrag = CardPreviewDrag()
    }

    private func beginTwoFinger(_ gesture: CardContactGestureRecognizer, at time: Double) {
        guard let view = sceneView, prepared else { return }
        let viewPoints = gesture.locations(in: view)
        let screenPoints = gesture.locations(in: window)
        guard viewPoints.count >= 2, screenPoints.count >= 2 else { return }
        finishPreviewDrag(cancelled: true)
        cancelReturnTimer()
        rotation.interruptAutomaticReturn(at: time)
        rotation.end(at: time, scheduleReturn: false)
        zoom.interruptReturn(at: time)
        renderOrientation()

        let focus = midpoint(viewPoints[0], viewPoints[1])
        let world: SCNVector3
        let local: SCNVector3
        if let hit = view.hitTest(focus, options: nil).first(where: { $0.node === cardNode }) {
            world = hit.worldCoordinates
            local = hit.localCoordinates
        } else {
            let depth = view.projectPoint(cardNode.position).z
            world = view.unprojectPoint(SCNVector3(Float(focus.x), Float(focus.y), depth))
            local = cardNode.convertPosition(world, from: nil)
        }
        zoomAnchorDepth = view.projectPoint(world).z
        zoom.begin(localAnchor: SIMD3<Double>(Double(local.x), Double(local.y), Double(local.z)), at: time)
        gesturePeakZoom = zoom.scale
        twoFingerInitialDistance = max(distance(viewPoints[0], viewPoints[1]), 1)
        twoFingerInitialAngle = angle(viewPoints[0], viewPoints[1])
        rotation.beginPhotoTransform(at: time)
        twoFingerActive = true
        contactNeedsRebase = true
    }

    private func updateTwoFinger(_ gesture: CardContactGestureRecognizer) {
        guard twoFingerActive, let view = sceneView else { return }
        let viewPoints = gesture.locations(in: view)
        let screenPoints = gesture.locations(in: window)
        guard viewPoints.count >= 2, screenPoints.count >= 2 else { return }
        let twist = normalizedAngle(angle(viewPoints[0], viewPoints[1]) - twoFingerInitialAngle)
        rotation.updatePhotoTransform(roll: twist)
        let focus = midpoint(viewPoints[0], viewPoints[1])
        let world = view.unprojectPoint(SCNVector3(Float(focus.x), Float(focus.y), zoomAnchorDepth))
        let factor = distance(viewPoints[0], viewPoints[1]) / twoFingerInitialDistance
        zoom.update(factor: factor,
                    worldFocus: SIMD3<Double>(Double(world.x), Double(world.y), Double(world.z)),
                    orientation: doubleQuaternion(renderedOrientation))
        gesturePeakZoom = max(gesturePeakZoom, zoom.scale)
        renderOrientation()
    }

    private func finishTwoFinger(at time: Double) {
        guard twoFingerActive else { return }
        onPreviewZoomEnd?(gesturePeakZoom)
        twoFingerActive = false
        rotation.end(at: time, scheduleReturn: false)
        rotation.returnToDefault(at: time, duration: CardZoom.returnDuration)
        zoom.end(at: time)
        startAnimationLink()
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    private func angle(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        atan2(b.y - a.y, b.x - a.x)
    }

    private func normalizedAngle(_ value: CGFloat) -> CGFloat {
        atan2(sin(value), cos(value))
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard interactive else { return false }
        // A new touch cancels the deadline immediately, before the recognizers
        // decide whether it will become a drag or a pinch.
        cancelReturnTimer()
        rotation.interruptAutomaticReturn(at: CACurrentMediaTime())
        renderOrientation()
        return true
    }

    private func cancelReturnTimer() {
        returnGeneration += 1
        returnWork?.cancel()
        returnWork = nil
    }

    private func armReturnTimer() {
        cancelReturnTimer()
        guard interactive, contact.activeTouchCount == 0, !twoFingerActive,
              let deadline = rotation.returnStartTime else { return }
        let generation = returnGeneration
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.returnGeneration == generation, self.interactive,
                  self.contact.activeTouchCount == 0, !self.twoFingerActive,
                  !self.rotation.isDragging, !self.zoom.isPinching else { return }
            self.returnWork = nil
            self.advanceAnimations(at: CACurrentMediaTime())
            self.startAnimationLink()
        }
        returnWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, deadline - CACurrentMediaTime()), execute: work)
    }

    private func startAnimationLink() {
        guard animationLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(animationFrame(_:)))
        link.add(to: .main, forMode: .common)
        animationLink = link
    }

    @objc private func animationFrame(_ link: CADisplayLink) {
        advanceAnimations(at: CACurrentMediaTime())
    }

    private func advanceAnimations(at time: Double) {
        rotation.advance(at: time)
        zoom.advance(at: time)
        renderOrientation()
        let turning = rotation.returnStartTime.map { time >= $0 } ?? false
        if !turning && !zoom.isReturning && !rotation.isEnteringPreview { stopAnimationLink() }
    }

    private func stopAnimationLink() {
        animationLink?.invalidate()
        animationLink = nil
    }

    private func renderOrientation() {
        SCNTransaction.begin(); SCNTransaction.animationDuration = 0; SCNTransaction.disableActions = true
        cardNode.simdOrientation = renderedOrientation
        cardNode.simdScale = SIMD3<Float>(repeating: Float(zoom.scale))
        cardNode.simdPosition = SIMD3<Float>(Float(zoom.translation.x), Float(zoom.translation.y), Float(zoom.translation.z))
        SCNTransaction.commit()
        renderMetal()
        if design.usesBrushedPBR && pbrReady { updatePBRZoomTier() }
        sceneView?.setNeedsDisplay()
    }

    private func renderMetal() {
        let activeView = design.plasticFinish != nil ? plasticSceneView
            : (design.digitalSkin != nil ? digitalSceneView : metalSceneView)
        guard let view = activeView,
              bounds.width > 0, bounds.height > 0 else { return }
        // Preserve the actual ID-1 aspect ratio inside the Figma artwork slot.
        let units = max(PlataMetalV1Geometry.width / 100,
                        PlataMetalV1Geometry.height / Float(100 * bounds.height / bounds.width))
        let card = design.plasticFinish != nil ? plasticCoordinator?.card
            : (design.digitalSkin != nil ? digitalCoordinator?.card : metalCoordinator?.card)
        guard let card else { return }
        // The renderer installs its studio camera while loading the card. Set
        // the gallery projection once afterwards, not on every 120 Hz gesture
        // or entrance tick. Only its position depends on viewport geometry.
        if galleryCameras.insert(ObjectIdentifier(view)).inserted {
            view.studioCamera.camera = .init(near: 0.0001, far: 10, fieldOfViewInDegrees: 28)
        }
        let cameraPosition = cameraNode.simdPosition * units
        if view.studioCamera.position != cameraPosition { view.studioCamera.position = cameraPosition }
        card.orientation = renderedOrientation
        card.scale = SIMD3<Float>(repeating: Float(zoom.scale))
        card.position = cardNode.simdPosition * units
    }

    private func requestPBRStandard() {
        guard design.usesBrushedPBR, sceneView != nil else { return }
        for side in ["front", "back", "edge"] where pbrStandard[side] == nil && !pbrLoading.contains("standard/\(side)") {
            let key = "standard/\(side)"
            let generation = pbrGeneration
            let options = faceOptions
            pbrLoading.insert(key)
            BrushedPBR.load(side: side, tier: "standard", options: options) { [weak self] material in
                guard let self, generation == self.pbrGeneration, self.design.usesBrushedPBR else { return }
                self.pbrLoading.remove(key)
                if let material { self.pbrStandard[side] = material }
                guard let front = self.pbrStandard["front"], let back = self.pbrStandard["back"],
                      let edge = self.pbrStandard["edge"] else { return }
                self.pbrReady = true
                self.cardNode.geometry?.materials = [front, back, edge]
                self.pbrDisplayedZoomSide = nil
                self.updateVisibility()
                self.updatePBRZoomTier()
            }
        }
    }

    private func updatePBRZoomTier() {
        guard pbrReady, let front = pbrStandard["front"], let back = pbrStandard["back"],
              let edge = pbrStandard["edge"] else { return }
        let side: String? = zoom.scale >= 1.5
            ? (renderedOrientation.act(SIMD3<Float>(0, 0, 1)).z >= 0 ? "front" : "back") : nil
        if let side, pbrZoom?.side != side, !pbrLoading.contains("zoom/\(side)") {
            // Keep one 6K face at most. Release it as soon as the visible side changes.
            pbrZoom = nil
            let key = "zoom/\(side)"
            let generation = pbrGeneration
            let options = faceOptions
            pbrLoading.insert(key)
            BrushedPBR.load(side: side, tier: "zoom", options: options) { [weak self] material in
                guard let self, generation == self.pbrGeneration else { return }
                self.pbrLoading.remove(key)
                guard let material else { return }
                let visibleSide = self.renderedOrientation.act(SIMD3<Float>(0, 0, 1)).z >= 0 ? "front" : "back"
                guard self.zoom.scale >= 1.5, visibleSide == side else { return }
                self.pbrZoom = (side, material)
                self.updatePBRZoomTier()
            }
        }
        let nextSide = side == pbrZoom?.side ? side : nil
        if pbrDisplayedZoomSide != nextSide {
            cardNode.geometry?.materials = [nextSide == "front" ? pbrZoom!.material : front,
                                            nextSide == "back" ? pbrZoom!.material : back, edge]
            pbrDisplayedZoomSide = nextSide
        }
        if side == nil { pbrZoom = nil }
    }

    private var renderedOrientation: simd_quatf {
        // Conjugate screen-space manipulation into the renderer, whose SwiftUI
        // container is rotated clockwise by a quarter turn in preview.
        let basis = quarterTurned
            ? simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))
            : simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 1))
        return basis * rotation.orientation * basis.inverse
    }

    private func doubleQuaternion(_ value: simd_quatf) -> simd_quatd {
        simd_quatd(ix: Double(value.imag.x), iy: Double(value.imag.y),
                   iz: Double(value.imag.z), r: Double(value.real))
    }

    func stop() {
        cancelReturnTimer()
        stopAnimationLink()
        rotation.end(at: CACurrentMediaTime(), scheduleReturn: false)
        rotation.interruptAutomaticReturn(at: CACurrentMediaTime())
        zoom.reset()
        twoFingerActive = false
        sceneView?.isPlaying = false
    }
    func releaseResources() {
        stop()
        discardScene()
    }
    private func discardScene() {
        galleryCameras.removeAll()
        plasticLoadTask?.cancel()
        plasticLoadTask = nil
        plasticCoordinator?.cancelTasks()
        plasticCoordinator = nil
        plasticSceneView?.scene.anchors.removeAll()
        plasticSceneView?.removeFromSuperview()
        plasticSceneView = nil
        digitalLoadTask?.cancel()
        digitalLoadTask = nil
        digitalCoordinator?.buildTask?.cancel()
        digitalCoordinator?.appearanceTask?.cancel()
        digitalCoordinator?.prewarmTask?.cancel()
        digitalCoordinator = nil
        digitalSceneView?.scene.anchors.removeAll()
        digitalSceneView?.removeFromSuperview()
        digitalSceneView = nil
        metalLoadTask?.cancel()
        metalLoadTask = nil
        metalCoordinator?.task?.cancel()
        metalCoordinator = nil
        metalSceneView?.scene.anchors.removeAll()
        metalSceneView?.removeFromSuperview()
        metalSceneView = nil
        pbrGeneration += 1
        pbrLoading.removeAll()
        pbrStandard.removeAll()
        pbrZoom = nil
        pbrDisplayedZoomSide = nil
        pbrReady = false
        sceneView?.scene = nil
        sceneView?.removeFromSuperview()
        sceneView = nil
        cardNode.removeFromParentNode()
        cardNode.geometry = nil
        cameraNode.removeFromParentNode()
        prepared = false
        lastSize = .zero
        lastViewportSide = 0
        proxyGeometryHeight = 0
        proxyGeometries.removeAll()
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop() }
    }
}

/// Unlike a long press, this recognizer ends only when the final finger lifts.
/// Adding/removing the second pinch finger emits a change so the single-finger
/// rotation can rebase without treating a centroid jump as movement.
private final class CardContactGestureRecognizer: UIGestureRecognizer {
    private var activeTouches: [UITouch] = []
    private var latestTouch: UITouch?
    var activeTouchCount: Int { activeTouches.count }

    func latestLocation(in view: UIView?) -> CGPoint {
        latestTouch?.location(in: view) ?? .zero
    }

    func locations(in view: UIView?) -> [CGPoint] {
        activeTouches.map { $0.location(in: view) }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches where !activeTouches.contains(touch) {
            activeTouches.append(touch)
        }
        latestTouch = activeTouches.first
        state = state == .possible ? .began : .changed
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        latestTouch = activeTouches.first
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        activeTouches.removeAll { touches.contains($0) }
        latestTouch = activeTouches.first ?? touches.first
        state = activeTouches.isEmpty ? .ended : .changed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        activeTouches.removeAll { touches.contains($0) }
        latestTouch = activeTouches.first ?? touches.first
        state = activeTouches.isEmpty ? .cancelled : .changed
    }

    override func reset() {
        super.reset()
        activeTouches.removeAll()
        latestTouch = nil
    }
}

/// Four joined contour rings plus two caps form a closed solid. Front/back UVs
/// are independent, with mirrored U on the reverse to keep its text readable.
private enum CardSolid {
    /// The PBR card uses explicit tangent vectors and perimeter UVs. The older
    /// gallery designs keep their original geometry and shading path intact.
    static func brushedGeometry(width: CGFloat, height: CGFloat, depth: CGFloat,
                                materials: [SCNMaterial]) -> SCNGeometry {
        let w = Float(width), h = Float(height), d = Float(depth), bevel: Float = 0.12
        let radius = h * 0.10, segments = 32
        let centers: [SIMD2<Float>] = [.init(w/2-radius,h/2-radius), .init(-w/2+radius,h/2-radius),
                                       .init(-w/2+radius,-h/2+radius), .init(w/2-radius,-h/2+radius)]
        var contour: [SIMD2<Float>] = [], outward: [SIMD2<Float>] = []
        for corner in 0..<4 { for i in 0...segments {
            let angle = (Float(corner) + Float(i)/Float(segments)) * .pi/2
            let normal = SIMD2<Float>(cos(angle), sin(angle))
            contour.append(centers[corner] + normal * radius)
            outward.append(normal)
        }}
        var positions: [SCNVector3] = [], normals: [SCNVector3] = [], uv: [CGPoint] = []
        var tangents: [SIMD4<Float>] = [], front: [Int32] = [], back: [Int32] = [], edge: [Int32] = []
        func vertex(_ p: SIMD3<Float>, _ n: SIMD3<Float>, _ t: SIMD3<Float>, _ point: CGPoint) -> Int32 {
            positions.append(SCNVector3(p.x,p.y,p.z))
            normals.append(SCNVector3(n.x,n.y,n.z))
            tangents.append(SIMD4<Float>(t.x,t.y,t.z,1))
            uv.append(point)
            return Int32(positions.count-1)
        }
        func faceUV(_ p: SIMD2<Float>, back: Bool = false) -> CGPoint {
            CGPoint(x: CGFloat(0.5 + (back ? -p.x : p.x)/w), y: CGFloat(0.5-p.y/h))
        }
        let frontCenter = vertex(.init(0,0,d/2),.init(0,0,1),.init(1,0,0),.init(x:0.5,y:0.5))
        let frontRing = contour.indices.map { i in
            let p = contour[i] - outward[i]*bevel
            return vertex(.init(p.x,p.y,d/2),.init(0,0,1),.init(1,0,0),faceUV(p))
        }
        let backCenter = vertex(.init(0,0,-d/2),.init(0,0,-1),.init(-1,0,0),.init(x:0.5,y:0.5))
        let backRing = contour.indices.map { i in
            let p = contour[i] - outward[i]*bevel
            return vertex(.init(p.x,p.y,-d/2),.init(0,0,-1),.init(-1,0,0),faceUV(p,back:true))
        }
        let count = contour.count
        var lengths: [Float] = [0]
        for i in 1...count { lengths.append(lengths.last! + simd_length(contour[i%count]-contour[i-1])) }
        for i in 0..<count {
            let j = (i+1)%count
            front += [frontCenter,frontRing[i],frontRing[j]]
            back += [backCenter,backRing[j],backRing[i]]
        }
        var rings: [(Float,Float,Float,Float)] = []
        for i in 0...6 {
            let a = Float(i)/6 * .pi/2
            rings.append((bevel*(1-sin(a)), d/2-bevel+bevel*cos(a), sin(a), cos(a)))
        }
        for i in 0...6 {
            let a = .pi/2 + Float(i)/6 * .pi/2
            rings.append((bevel*(1-sin(a)), -d/2+bevel+bevel*cos(a), sin(a), cos(a)))
        }
        for ring in 0..<rings.count-1 { for i in 0..<count {
            let j = (i+1)%count
            let a = contour[i]-outward[i]*rings[ring].0
            let b = contour[j]-outward[j]*rings[ring].0
            let c = contour[i]-outward[i]*rings[ring+1].0
            let e = contour[j]-outward[j]*rings[ring+1].0
            func normal(_ index: Int, _ r: Int) -> SIMD3<Float> {
                .init(outward[index].x*rings[r].2, outward[index].y*rings[r].2, rings[r].3)
            }
            let ti = SIMD3<Float>(-outward[i].y,outward[i].x,0)
            let tj = SIMD3<Float>(-outward[j].y,outward[j].x,0)
            let u0 = CGFloat(lengths[i]/lengths[count]), u1 = CGFloat(lengths[i+1]/lengths[count])
            let v0 = CGFloat(0.5-rings[ring].1/d), v1 = CGFloat(0.5-rings[ring+1].1/d)
            let x0 = vertex(.init(a.x,a.y,rings[ring].1),normal(i,ring),ti,.init(x:u0,y:v0))
            let x1 = vertex(.init(c.x,c.y,rings[ring+1].1),normal(i,ring+1),ti,.init(x:u0,y:v1))
            let x2 = vertex(.init(b.x,b.y,rings[ring].1),normal(j,ring),tj,.init(x:u1,y:v0))
            let x3 = vertex(.init(e.x,e.y,rings[ring+1].1),normal(j,ring+1),tj,.init(x:u1,y:v1))
            edge += [x0,x1,x2,x2,x1,x3]
        }}
        let tangentData = tangents.withUnsafeBytes { Data($0) }
        let tangentSource = SCNGeometrySource(data:tangentData,semantic:.tangent,vectorCount:tangents.count,
                                              usesFloatComponents:true,componentsPerVector:4,bytesPerComponent:4,
                                              dataOffset:0,dataStride:16)
        let geometry = SCNGeometry(sources:[SCNGeometrySource(vertices:positions),SCNGeometrySource(normals:normals),
                                            SCNGeometrySource(textureCoordinates:uv),tangentSource],
                                   elements:[SCNGeometryElement(indices:front,primitiveType:.triangles),
                                             SCNGeometryElement(indices:back,primitiveType:.triangles),
                                             SCNGeometryElement(indices:edge,primitiveType:.triangles)])
        geometry.materials = materials
        return geometry
    }

    static func geometry(width: CGFloat, height: CGFloat, depth: CGFloat, materials: [SCNMaterial]) -> SCNGeometry {
        let w = Float(width), h = Float(height), d = Float(depth)
        let radius = h * 0.10
        let bevel: Float = 0.12
        let segments = 12
        var contour: [SIMD2<Float>] = []
        var outward: [SIMD2<Float>] = []
        let centers: [SIMD2<Float>] = [.init(w/2-radius,h/2-radius), .init(-w/2+radius,h/2-radius),
                                       .init(-w/2+radius,-h/2+radius), .init(w/2-radius,-h/2+radius)]
        for corner in 0..<4 {
            for i in 0...segments {
                let angle = (Float(corner) + Float(i) / Float(segments)) * .pi / 2
                let n = SIMD2<Float>(cos(angle), sin(angle))
                contour.append(centers[corner] + n * radius)
                outward.append(n)
            }
        }
        var positions: [SCNVector3] = [], normals: [SCNVector3] = [], uvs: [CGPoint] = []
        var front: [Int32] = [], back: [Int32] = [], sides: [Int32] = []
        func vertex(_ p: SIMD3<Float>, _ n: SIMD3<Float>, _ uv: CGPoint) -> Int32 {
            positions.append(SCNVector3(p.x,p.y,p.z)); normals.append(SCNVector3(n.x,n.y,n.z)); uvs.append(uv)
            return Int32(positions.count - 1)
        }
        func uv(_ p: SIMD2<Float>, back: Bool = false) -> CGPoint {
            CGPoint(x: CGFloat(back ? 0.5 - p.x/w : p.x/w + 0.5), y: CGFloat(0.5 - p.y/h))
        }
        let count = contour.count
        let frontCenter = vertex(.init(0,0,d/2), .init(0,0,1), .init(x:0.5,y:0.5))
        let frontRing = contour.indices.map { i in
            let p = contour[i] - outward[i] * bevel
            return vertex(.init(p.x,p.y,d/2), .init(0,0,1), uv(p))
        }
        let backCenter = vertex(.init(0,0,-d/2), .init(0,0,-1), .init(x:0.5,y:0.5))
        let backRing = contour.indices.map { i in
            let p = contour[i] - outward[i] * bevel
            return vertex(.init(p.x,p.y,-d/2), .init(0,0,-1), uv(p, back: true))
        }
        for i in 0..<count {
            let j = (i+1)%count
            front += [frontCenter, frontRing[i], frontRing[j]]
            back += [backCenter, backRing[j], backRing[i]]
        }
        let rings: [(Float,Float)] = [(bevel,d/2),(0,d/2-bevel),(0,-d/2+bevel),(bevel,-d/2)]
        for ring in 0..<3 {
            for i in 0..<count {
                let j = (i+1)%count
                let a = contour[i] - outward[i] * rings[ring].0
                let b = contour[j] - outward[j] * rings[ring].0
                let c = contour[i] - outward[i] * rings[ring+1].0
                let e = contour[j] - outward[j] * rings[ring+1].0
                let slope: Float = ring == 0 ? 1 : ring == 2 ? -1 : 0
                let ni = simd_normalize(SIMD3<Float>(outward[i].x,outward[i].y,slope))
                let nj = simd_normalize(SIMD3<Float>(outward[j].x,outward[j].y,slope))
                let v0 = vertex(.init(a.x,a.y,rings[ring].1),ni,.zero)
                let v1 = vertex(.init(c.x,c.y,rings[ring+1].1),ni,.zero)
                let v2 = vertex(.init(b.x,b.y,rings[ring].1),nj,.zero)
                let v3 = vertex(.init(e.x,e.y,rings[ring+1].1),nj,.zero)
                sides += [v0,v1,v2,v2,v1,v3]
            }
        }
        let geometry = SCNGeometry(sources: [.init(vertices: positions), .init(normals: normals), .init(textureCoordinates: uvs)],
                                   elements: [SCNGeometryElement(indices: front, primitiveType: .triangles),
                                              SCNGeometryElement(indices: back, primitiveType: .triangles),
                                              SCNGeometryElement(indices: sides, primitiveType: .triangles)])
        geometry.materials = materials
        return geometry
    }
}

/// Loads only the selected metal design. PNG channel maps remain linear; sRGB
/// decoding is applied solely to Base Color. Material creation stays on main.
private enum BrushedPBR {
    private static let queue = DispatchQueue(label: "plata.brushed-pbr", qos: .userInitiated)

    static func url(_ path: String) -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let result = resourceURL.appendingPathComponent("PBRMaterials").appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: result.path) ? result : nil
    }

    private struct Maps {
        let base: MTLTexture
        let metalness: MTLTexture
        let roughness: MTLTexture
        let normal: MTLTexture

        func material() -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.diffuse.contents = base
            material.metalness.contents = metalness
            material.roughness.contents = roughness
            material.normal.contents = normal
            for property in [material.diffuse, material.metalness, material.roughness, material.normal] {
                property.minificationFilter = .linear
                property.magnificationFilter = .linear
                property.mipFilter = .linear
                property.maxAnisotropy = 8
                property.wrapS = .clamp
                property.wrapT = .clamp
            }
            material.metalness.textureComponents = .red
            material.roughness.textureComponents = .red
            material.isDoubleSided = false
            return material
        }
    }

    static func load(side: String, tier: String, options: CardFaceOptions,
                     completion: @escaping (SCNMaterial?) -> Void) {
        queue.async {
            do {
                guard let device = MTLCreateSystemDefaultDevice() else { throw LoadError.noGPU }
                let loader = MTKTextureLoader(device: device)
                let useDemo = side == "front"
                    ? (!options.rendersDynamicDetails ||
                       (options.showsCardholderName && options.cardholderName == "CARD HOLDER"))
                    : side == "back" && options.showsCardNumber
                let kind = useDemo ? "demo" : "materials"
                let prefix = "brushed-metal/\(kind)/\(side)/\(tier)"
                func texture(_ filename: String, color: Bool) throws -> MTLTexture {
                    guard let file = url("\(prefix)/\(filename).png") else { throw LoadError.missingFile }
                    return try loader.newTexture(URL: file, options: [
                        .SRGB: color, .generateMipmaps: true,
                        .origin: MTKTextureLoader.Origin.topLeft.rawValue
                    ])
                }
                let base: MTLTexture
                if side == "front", options.rendersDynamicDetails,
                   options.showsCardholderName, !options.cardholderName.isEmpty,
                   options.cardholderName != "CARD HOLDER" {
                    guard let file = url("\(prefix)/basecolor.png"),
                          let clean = UIImage(contentsOfFile: file.path) else { throw LoadError.missingFile }
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    let rendered = UIGraphicsImageRenderer(size: clean.size, format: format).image { _ in
                        clean.draw(at: .zero)
                        NSString(string: options.cardholderName.uppercased()).draw(
                            in: CGRect(x:clean.size.width*0.037, y:clean.size.height*0.892,
                                       width:clean.size.width*0.39, height:clean.size.height*0.06),
                            withAttributes:[.font:UIFont(name:"Arial-BoldMT",size:clean.size.height*0.045)
                                            ?? UIFont.systemFont(ofSize:clean.size.height*0.045,weight:.bold),
                                            .foregroundColor:UIColor(white:0.24,alpha:1)])
                    }
                    guard let image = rendered.cgImage else { throw LoadError.missingFile }
                    base = try loader.newTexture(cgImage: image, options: [
                        .SRGB: true, .generateMipmaps: true,
                        .origin: MTKTextureLoader.Origin.topLeft.rawValue
                    ])
                } else {
                    base = try texture("basecolor", color: true)
                }
                let maps = try Maps(base: base,
                                    metalness: texture("metalness", color: false),
                                    roughness: texture("roughness", color: false),
                                    normal: texture("normal-scenekit", color: false))
                DispatchQueue.main.async { completion(maps.material()) }
            } catch {
                NSLog("PLATA PBR load failed for %@/%@: %@", side, tier, String(describing: error))
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    private enum LoadError: Error { case noGPU, missingFile }
}

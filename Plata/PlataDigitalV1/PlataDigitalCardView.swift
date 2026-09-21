import SwiftUI
import RealityKit
import OSLog

enum PlataDigitalLight: String, CaseIterable {
    case studio, soft, night
    var title: String { rawValue.capitalized }
    var intensity: Float { switch self { case .studio: -0.7; case .soft: -1.5; case .night: -3 } }
}

/// Digital uses the same fitted camera/physical proportions as Metal, in a non-AR scene.
struct PlataDigitalCardView: UIViewRepresentable {
    var skin: PlataDigitalSkin = .amanecer
    var pose: PlataMetalV1Pose = .frontGrazing
    var poseRevision = 0
    var light: PlataDigitalLight = .studio
    var resourceBundle: Bundle = .main

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PlataMetalV1SceneView {
        let view = PlataMetalV1SceneView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(white: 0.045, alpha: 1))
        view.renderOptions.insert(.disableMotionBlur)
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "plata-digital-scene"
        view.accessibilityHint = "Drag to rotate. Pinch to zoom. Double tap to reset."
        context.coordinator.start(view, configuration: self)
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:))))
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.reset(_:)))
        tap.numberOfTapsRequired = 2
        view.addGestureRecognizer(tap)
        return view
    }
    func updateUIView(_ view: PlataMetalV1SceneView, context: Context) { context.coordinator.update(self) }
    static func dismantleUIView(_ view: PlataMetalV1SceneView, coordinator: Coordinator) {
        coordinator.buildTask?.cancel(); coordinator.appearanceTask?.cancel(); coordinator.prewarmTask?.cancel()
        view.scene.anchors.removeAll()
    }

    @MainActor final class Coordinator: NSObject {
        private static let logger = Logger(subsystem: "com.sytykhandrei.platacards", category: "PlataDigital")
        weak var view: PlataMetalV1SceneView?
        var card: Entity?
        var buildTask: Task<Void, Never>?
        var appearanceTask: Task<Void, Never>?
        var prewarmTask: Task<Void, Never>?
        private var config = PlataDigitalCardView()
        private var yaw: Float = 0.3
        private var pitch: Float = -0.16
        private var pinchStart: Float = 1
        private var surfaceReady = false
        private var failure: String?
        private var key: DirectionalLight?

        func start(_ view: PlataMetalV1SceneView, configuration: PlataDigitalCardView) {
            self.view = view
            config = configuration
            yaw = config.pose.yaw; pitch = config.pose.pitch
            view.showStatus("Loading Digital…")
            buildTask = Task { @MainActor [weak self, weak view] in
                guard let self, let view else { return }
                do {
                    let environment = try await PlataDigitalCardMaterial.environment(bundle: config.resourceBundle)
                    let card = try await PlataDigitalCardMaterial.makeCard()
                    try Task.checkCancellation()
                    card.isEnabled = false
                    self.card = card
                    let root = AnchorEntity(world: .zero)
                    root.addChild(card)
                    view.environment.lighting.resource = environment
                    view.studioCamera.camera = .init(near: 0.001, far: 10, fieldOfViewInDegrees: 34)
                    root.addChild(view.studioCamera)
                    let key = DirectionalLight()
                    key.orientation = simd_quatf(angle: -0.7, axis: [1,0,0]) * simd_quatf(angle: 0.7, axis: [0,1,0])
                    root.addChild(key); self.key = key
                    view.scene.addAnchor(root)
                    applyLight(); applyPose()
                    refreshSkin()
                    view.setNeedsLayout()
                } catch is CancellationError {
                } catch { report(error) }
            }
        }

        func update(_ next: PlataDigitalCardView) {
            let skinChanged = next.skin != config.skin
            let poseChanged = next.pose != config.pose || next.poseRevision != config.poseRevision
            let lightChanged = next.light != config.light
            config = next
            if poseChanged { yaw = next.pose.yaw; pitch = next.pose.pitch; view?.zoomFactor = 1; applyPose() }
            if lightChanged { applyLight() }
            if skinChanged { refreshSkin() }
        }

        private func refreshSkin() {
            guard let card else { return }
            appearanceTask?.cancel()
            prewarmTask?.cancel()
            failure = nil
            let skin = config.skin
            PlataDigitalMaterialCache.shared.focus(on: skin)
            if let ready = PlataDigitalMaterialCache.shared.cached(skin) {
                do {
                    try PlataDigitalCardMaterial.apply(ready, skin: skin, card: card)
                    appearanceTask = nil
                    finishAppearance(skin, card: card)
                } catch { report(error) }
                return
            }
            appearanceTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    try await PlataDigitalCardMaterial.updateSkin(skin, card: card)
                    try Task.checkCancellation()
                    finishAppearance(skin, card: card)
                } catch is CancellationError {
                } catch { report(error) }
            }
        }
        private func finishAppearance(_ skin: PlataDigitalSkin, card: Entity) {
            card.name = "PLATA Digital — \(skin.title)"
            card.isEnabled = true
            surfaceReady = true
            updateStatus()
            prewarmTask = Task { @MainActor in
                try? await PlataDigitalMaterialCache.shared.prewarm(around: skin)
            }
        }
        private func report(_ error: Error) {
            guard !Task.isCancelled else { return }
            failure = error.localizedDescription
            Self.logger.error("\(error.localizedDescription, privacy: .public)")
            view?.showStatus(error.localizedDescription)
        }
        private func applyLight() {
            view?.environment.lighting.intensityExponent = config.light.intensity
            key?.light.intensity = config.light == .studio ? 180 : (config.light == .soft ? 60 : 0)
            updateStatus()
        }
        private func applyPose() {
            card?.orientation = simd_quatf(angle: pitch, axis: [1,0,0]) * simd_quatf(angle: yaw, axis: [0,1,0])
            updateStatus()
        }
        private func updateStatus() {
            guard failure == nil else { return }
            guard surfaceReady else { view?.showStatus("Loading Digital…"); return }
            view?.showStatus(nil)
            let zoom = String(format: "%.2f", view?.zoomFactor ?? 1)
            view?.accessibilityLabel = "PLATA Digital, \(config.skin.title), interactive 3D card"
            view?.accessibilityValue = "Ready; skin \(config.skin.rawValue); yaw \(Int(yaw * 180 / .pi)); pitch \(Int(pitch * 180 / .pi)); zoom \(zoom); light \(config.light.rawValue)"
        }
        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            guard card != nil else { return }
            if recognizer.state == .changed {
                let delta = recognizer.translation(in: recognizer.view)
                yaw = (yaw + Float(delta.x) * 0.008).truncatingRemainder(dividingBy: 2 * .pi)
                pitch = min(max(pitch + Float(delta.y) * 0.006, -.pi / 2), .pi / 2)
                applyPose()
            }
            recognizer.setTranslation(.zero, in: recognizer.view)
        }
        @objc func pinch(_ recognizer: UIPinchGestureRecognizer) {
            guard card != nil, let view else { return }
            if recognizer.state == .began { pinchStart = view.zoomFactor }
            if recognizer.state == .began || recognizer.state == .changed {
                view.zoomFactor = min(max(pinchStart * Float(recognizer.scale), 1), 3)
                view.layoutIfNeeded(); updateStatus()
            }
        }
        @objc func reset(_ recognizer: UITapGestureRecognizer) { view?.zoomFactor = 1; updateStatus() }
    }
}

import SwiftUI
import RealityKit
import OSLog

enum PlataPlasticLight: String, CaseIterable {
    case studio, soft, night
    var title: String { rawValue.capitalized }
    var intensity: Float { switch self { case .studio: -0.7; case .soft: -1.5; case .night: -3 } }
}

/// Plastic uses the same fitted camera/physical proportions as Metal, in a non-AR scene.
struct PlataPlasticCardView: UIViewRepresentable {
    var skin: PlataPlasticFinish = .plata
    var details = PlataPlasticDetails()
    var pose: PlataMetalV1Pose = .frontGrazing
    var poseRevision = 0
    var light: PlataPlasticLight = .studio
    var resourceBundle: Bundle = .main

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PlataMetalV1SceneView {
        let view = PlataMetalV1SceneView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor(white: 0.045, alpha: 1))
        view.renderOptions.insert(.disableMotionBlur)
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "plata-plastic-scene"
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
        coordinator.cancelTasks()
        view.scene.anchors.removeAll()
    }

    @MainActor final class Coordinator: NSObject {
        private static let logger = Logger(subsystem: "com.sytykhandrei.platacards", category: "PlataPlastic")
        weak var view: PlataMetalV1SceneView?
        var card: Entity?
        var buildTask: Task<Void, Never>?
        var appearanceTask: Task<Void, Never>?
        // Kept for existing adapter await/cancel callers; the single appearance task includes details.
        var detailsTask: Task<Void, Never>?
        var prewarmTask: Task<Void, Never>?
        private var appearanceRevision = 0
        private var displayedAppearance: PlataPlasticCardMaterial.Appearance?
        private var config = PlataPlasticCardView()
        private var yaw: Float = 0.3
        private var pitch: Float = -0.16
        private var pinchStart: Float = 1
        private var failure: String?
        private var loaderVisible = false
        private var key: DirectionalLight?
        private var inspectionLight: PointLight?

        func start(_ view: PlataMetalV1SceneView, configuration: PlataPlasticCardView) {
            self.view = view
            config = configuration
            yaw = config.pose.yaw; pitch = config.pose.pitch
            showLoading(true)
            buildTask = Task { @MainActor [weak self, weak view] in
                guard let self, let view else { return }
                do {
                    let environment = try await PlataPlasticCardMaterial.environment(bundle: config.resourceBundle)
                    let card = try await PlataPlasticCardMaterial.makeCard(bundle: config.resourceBundle)
                    try Task.checkCancellation()
                    self.card = card
                    let root = AnchorEntity(world: .zero)
                    card.isEnabled = false
                    root.addChild(card)
                    view.environment.lighting.resource = environment
                    view.studioCamera.camera = .init(near: 0.001, far: 10, fieldOfViewInDegrees: 34)
                    root.addChild(view.studioCamera)
                    let key = DirectionalLight()
                    key.orientation = simd_quatf(angle: -0.7, axis: [1,0,0]) * simd_quatf(angle: 0.7, axis: [0,1,0])
                    root.addChild(key); self.key = key
                    // A real studio emitter gives glossy plastic a moving specular reflection.
                    let inspectionLight = PointLight()
                    inspectionLight.position = [-0.025, 0.035, 0.12]
                    inspectionLight.light.attenuationRadius = 0.5
                    root.addChild(inspectionLight); self.inspectionLight = inspectionLight
                    view.scene.addAnchor(root)
                    applyLight(); applyPose()
                    refreshAppearance()
                    view.setNeedsLayout()
                } catch is CancellationError {
                    // Shared resources may be purged while the initial card is loading.
                    // Retry current demand, but never restart a dismantled/cancelled view.
                    if !Task.isCancelled, self.view === view, self.card == nil {
                        start(view, configuration: config)
                    }
                } catch { report(error) }
            }
        }

        func update(_ next: PlataPlasticCardView) {
            let skinChanged = next.skin != config.skin
            let detailsChanged = next.details != config.details
            let poseChanged = next.pose != config.pose || next.poseRevision != config.poseRevision
            let lightChanged = next.light != config.light
            config = next
            if poseChanged { yaw = next.pose.yaw; pitch = next.pose.pitch; view?.zoomFactor = 1; applyPose() }
            if lightChanged || skinChanged { applyLight() }
            if detailsChanged || skinChanged { refreshAppearance() }
        }

        func cancelTasks() {
            appearanceRevision += 1
            buildTask?.cancel(); appearanceTask?.cancel(); detailsTask?.cancel(); prewarmTask?.cancel()
        }
        private func refreshAppearance() {
            guard let card else { return }
            appearanceRevision += 1
            let revision = appearanceRevision
            appearanceTask?.cancel(); prewarmTask?.cancel(); detailsTask = nil
            failure = nil
            let skin = config.skin, details = config.details, bundle = config.resourceBundle
            if let ready = PlataPlasticCardMaterial.cachedAppearance(skin, details: details, bundle: bundle) {
                do {
                    try commit(ready, to: card)
                    appearanceTask = nil
                    prewarm(around: skin, details: details, bundle: bundle)
                } catch { report(error) }
                return
            }
            updateStatus()
            appearanceTask = Task { @MainActor [weak self, weak card] in
                guard let self, let card else { return }
                do {
                    let ready = try await PlataPlasticCardMaterial.prepare(skin, details: details, bundle: bundle)
                    try Task.checkCancellation()
                    guard revision == appearanceRevision, self.card === card,
                          config.skin == skin, config.details == details else { return }
                    try commit(ready, to: card)
                    prewarm(around: skin, details: details, bundle: bundle)
                } catch is CancellationError {
                    // A pressure purge cancels shared preparation, not the current
                    // consumer. Retry only that still-current demand, without prefetch.
                    if !Task.isCancelled, revision == appearanceRevision { refreshAppearance() }
                } catch {
                    guard revision == appearanceRevision else { return }
                    report(error)
                }
            }
        }
        private func commit(_ appearance: PlataPlasticCardMaterial.Appearance, to card: Entity) throws {
            try PlataPlasticCardMaterial.apply(appearance, to: card)
            displayedAppearance = appearance
            card.isEnabled = true
            updateStatus()
        }
        private func prewarm(around skin: PlataPlasticFinish, details: PlataPlasticDetails, bundle: Bundle) {
            let finishes = [skin] + PlataPlasticFinish.allCases.filter { $0 != skin }
            prewarmTask = Task { @MainActor in
                do { try await PlataPlasticCardMaterial.prewarm(finishes: finishes, details: details, bundle: bundle) }
                catch is CancellationError { }
                catch { Self.logger.error("Plastic prewarm: \(error.localizedDescription, privacy: .public)") }
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
            // On glossy Cobalto this tiny emitter burns a white spot into the
            // open part of the L. Keep its original gloss/clearcoat and studio
            // HDR reflections; omit only the point-source inspection highlight.
            inspectionLight?.light.intensity = config.light == .studio && config.skin != .cobalto ? 55 : 0
            updateStatus()
        }
        private func applyPose() {
            card?.orientation = simd_quatf(angle: pitch, axis: [1,0,0]) * simd_quatf(angle: yaw, axis: [0,1,0])
            updateStatus()
        }
        private func showLoading(_ visible: Bool) {
            if visible && !loaderVisible { PlataPlasticDiagnostics.record(.loaderShown) }
            loaderVisible = visible
            view?.showStatus(visible ? "Loading Plastic…" : nil)
        }
        private func updateStatus() {
            guard failure == nil else { return }
            guard let displayed = displayedAppearance else { showLoading(true); return }
            guard displayed.finish == config.skin, displayed.details == config.details else {
                // Keep the complete previous finish visible on a genuine cold miss.
                // Accessibility reports actual readiness instead of claiming the new colour is ready.
                showLoading(false)
                view?.accessibilityValue = "Loading; requested skin \(config.skin.rawValue); displayed skin \(displayed.finish.rawValue)"
                return
            }
            showLoading(false)
            let zoom = String(format: "%.2f", view?.zoomFactor ?? 1)
            view?.accessibilityLabel = "PLATA Plastic, \(config.skin.title), interactive 3D card"
            view?.accessibilityValue = "Ready; skin \(config.skin.rawValue); yaw \(Int(yaw * 180 / .pi)); pitch \(Int(pitch * 180 / .pi)); zoom \(zoom); light \(config.light.rawValue); name \(config.details.showsName ? config.details.name : "hidden"); number \(config.details.showsNumber ? "visible" : "hidden")"
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

import SwiftUI
import UIKit
import SceneKit
import simd

struct MetalCard: UIViewRepresentable {
    var interactive: Bool
    var prepareForInteraction: Bool

    func makeUIView(context: Context) -> MetalCardSurface { MetalCardSurface() }
    func updateUIView(_ view: MetalCardSurface, context: Context) {
        view.prepareForInteraction = prepareForInteraction
        view.interactive = interactive
    }
    static func dismantleUIView(_ uiView: MetalCardSurface, coordinator: ()) { uiView.stop() }
}

/// A closed, bevelled metal solid. One finger controls yaw; two fingers combine
/// anchored zoom with free pitch, yaw and roll.
final class MetalCardSurface: UIView, UIGestureRecognizerDelegate {
    private static let front = UIImage(named: "hola-platacard")?.preparingForDisplay()
    private static let back = UIImage(named: "hola-platacard-back")?.preparingForDisplay()
    private let restingFace = CALayer()
    private var sceneView: SCNView?
    private let cardNode = SCNNode()
    private let cameraNode = SCNNode()
    private var rotation = CardPhysics()
    private var zoom = CardZoom()
    private var contact: CardContactGestureRecognizer!
    private var contactNeedsRebase = false
    private var twoFingerActive = false
    private var twoFingerInitialDistance: CGFloat = 1
    private var twoFingerInitialAngle: CGFloat = 0
    private var zoomAnchorDepth: Float = 0
    private var returnWork: DispatchWorkItem?
    private var returnGeneration = 0
    private var animationLink: CADisplayLink?
    private var lastSize = CGSize.zero
    private var prepared = false

    var prepareForInteraction = false {
        didSet {
            if prepareForInteraction { prepareScene() }
            else if !interactive { discardScene() }
        }
    }
    var interactive = false {
        didSet {
            guard oldValue != interactive else { return }
            contact.isEnabled = interactive
            if interactive { prepareScene() }
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
        restingFace.contents = Self.front?.cgImage
        restingFace.contentsGravity = .resize
        restingFace.masksToBounds = true
        layer.addSublayer(restingFace)
        contact = CardContactGestureRecognizer(target: self, action: #selector(handleContact(_:)))
        contact.isEnabled = false
        contact.delegate = self
        addGestureRecognizer(contact)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
        camera.wantsHDR = false
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode
        // Large, restrained studio fill keeps the supplied copper colour legible
        // while directional specular light moves over the actual rotated normals.
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor.white
        ambient.intensity = 800
        let fill = SCNNode(); fill.light = ambient
        scene.rootNode.addChildNode(fill)
        addLight(to: scene, position: SCNVector3(-90, 110, 220), intensity: 240)
        addLight(to: scene, position: SCNVector3(100, -80, -180), intensity: 200)
        scene.lightingEnvironment.contents = UIColor(white: 0.7, alpha: 1)
        scene.lightingEnvironment.intensity = 0.7
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
        let side = hypot(bounds.width, bounds.height) * 1.08
        view.frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
        guard lastSize != bounds.size else { return }
        lastSize = bounds.size
        let modelWidth: CGFloat = 100
        let modelHeight = modelWidth * bounds.height / bounds.width
        let halfFrustum = side / bounds.width * modelWidth / 2
        cameraNode.position = SCNVector3(0, 0, Float(halfFrustum / tan(14 * .pi / 180)) + 0.45)
        cardNode.geometry = CardSolid.geometry(width: modelWidth, height: modelHeight, depth: 0.9,
                                               materials: [faceMaterial(Self.front), faceMaterial(Self.back, isBack: true), edgeMaterial()])
        renderOrientation()
        if !prepared {
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
        let showSolid = interactive && prepared
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
                    finishTwoFinger(at: time)
                    contactNeedsRebase = true
                }
                if contactNeedsRebase || !rotation.isDragging {
                    beginSingleFinger(gesture, at: time)
                } else {
                    updateSingleFinger(gesture)
                }
            }
        case .ended:
            if twoFingerActive { finishTwoFinger(at: time) }
            rotation.end(at: time)
            armReturnTimer()
        case .cancelled, .failed:
            if twoFingerActive { finishTwoFinger(at: time) }
            rotation.end(at: time, scheduleReturn: interactive)
            if interactive { armReturnTimer() }
        default: break
        }
    }

    private func beginSingleFinger(_ gesture: CardContactGestureRecognizer, at time: Double) {
        guard gesture.activeTouchCount == 1 else { return }
        cancelReturnTimer()
        let p = gesture.latestLocation(in: window)
        let screenBounds = convert(bounds, to: window)
        rotation.begin(x: p.x, y: p.y, width: max(screenBounds.width, 1),
                       height: max(screenBounds.height, 1), at: time)
        contactNeedsRebase = false
    }

    private func updateSingleFinger(_ gesture: CardContactGestureRecognizer) {
        let p = gesture.latestLocation(in: window)
        rotation.update(x: p.x, y: p.y)
        renderOrientation()
    }

    private func beginTwoFinger(_ gesture: CardContactGestureRecognizer, at time: Double) {
        guard let view = sceneView, prepared else { return }
        let viewPoints = gesture.locations(in: view)
        let screenPoints = gesture.locations(in: window)
        guard viewPoints.count >= 2, screenPoints.count >= 2 else { return }
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
        twoFingerInitialDistance = max(distance(viewPoints[0], viewPoints[1]), 1)
        twoFingerInitialAngle = angle(viewPoints[0], viewPoints[1])
        let center = midpoint(screenPoints[0], screenPoints[1])
        let screenBounds = convert(bounds, to: window)
        rotation.beginFree(x: center.x, y: center.y, width: max(screenBounds.width, 1),
                           height: max(screenBounds.height, 1), at: time)
        twoFingerActive = true
        contactNeedsRebase = true
    }

    private func updateTwoFinger(_ gesture: CardContactGestureRecognizer) {
        guard twoFingerActive, let view = sceneView else { return }
        let viewPoints = gesture.locations(in: view)
        let screenPoints = gesture.locations(in: window)
        guard viewPoints.count >= 2, screenPoints.count >= 2 else { return }
        let center = midpoint(screenPoints[0], screenPoints[1])
        let twist = normalizedAngle(angle(viewPoints[0], viewPoints[1]) - twoFingerInitialAngle)
        rotation.updateFree(x: center.x, y: center.y, roll: twist)
        let focus = midpoint(viewPoints[0], viewPoints[1])
        let world = view.unprojectPoint(SCNVector3(Float(focus.x), Float(focus.y), zoomAnchorDepth))
        let factor = distance(viewPoints[0], viewPoints[1]) / twoFingerInitialDistance
        zoom.update(factor: factor,
                    worldFocus: SIMD3<Double>(Double(world.x), Double(world.y), Double(world.z)),
                    orientation: doubleQuaternion(renderedOrientation))
        renderOrientation()
    }

    private func finishTwoFinger(at time: Double) {
        guard twoFingerActive else { return }
        twoFingerActive = false
        rotation.end(at: time, scheduleReturn: false)
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
        if !turning && !zoom.isReturning { stopAnimationLink() }
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
        sceneView?.setNeedsDisplay()
    }

    private var renderedOrientation: simd_quatf {
        // Conjugate screen-space manipulation into the renderer, whose SwiftUI
        // container is rotated clockwise by a quarter turn in preview.
        let basis = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))
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
    private func discardScene() {
        sceneView?.scene = nil
        sceneView?.removeFromSuperview()
        sceneView = nil
        cardNode.removeFromParentNode()
        cardNode.geometry = nil
        cameraNode.removeFromParentNode()
        prepared = false
        lastSize = .zero
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

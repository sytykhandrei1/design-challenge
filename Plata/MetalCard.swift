import SwiftUI
import UIKit

struct MetalCard: UIViewRepresentable {
    var interactive: Bool
    var reduceMotion: Bool

    func makeUIView(context: Context) -> MetalCardSurface { MetalCardSurface() }
    func updateUIView(_ view: MetalCardSurface, context: Context) {
        view.reduceMotion = reduceMotion
        view.interactive = interactive
    }
    static func dismantleUIView(_ uiView: MetalCardSurface, coordinator: ()) { uiView.stop() }
}

final class MetalCardSurface: UIView {
    // One decoded bundled texture shared by all cards; no IO or texture generation on touch.
    private static let artwork = UIImage(named: "hola-platacard")?.preparingForDisplay()
    private let plate = CALayer()
    private let reflection = CAGradientLayer()
    private let shade = CAGradientLayer()
    private var physics = CardPhysics()
    private var displayLink: CADisplayLink?
    private var lastTimestamp = 0.0
    private let feedback = UIImpactFeedbackGenerator(style: .soft)
    private var contact: UILongPressGestureRecognizer!
    var reduceMotion = false
    var interactive = false {
        didSet {
            contact.isEnabled = interactive
            if interactive && !oldValue { feedback.prepare() }
            if !interactive && oldValue { physics.release(); wake() }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isMultipleTouchEnabled = false
        // Recognize contact immediately, before the sheet's drag-to-dismiss pan.
        contact = UILongPressGestureRecognizer(target: self, action: #selector(handleContact(_:)))
        contact.minimumPressDuration = 0
        contact.allowableMovement = .greatestFiniteMagnitude
        contact.isEnabled = false
        addGestureRecognizer(contact)
        plate.contents = Self.artwork?.cgImage
        plate.contentsGravity = .resize
        plate.masksToBounds = true
        layer.addSublayer(plate)
        reflection.colors = [UIColor.clear.cgColor, UIColor(white: 1, alpha: 0.05).cgColor,
                             UIColor(white: 1, alpha: 0.38).cgColor,
                             UIColor(white: 1, alpha: 0.05).cgColor, UIColor.clear.cgColor]
        reflection.locations = [0, 0.32, 0.5, 0.68, 1]
        reflection.startPoint = CGPoint(x: 0.1, y: 0)
        reflection.endPoint = CGPoint(x: 0.9, y: 1)
        shade.colors = [UIColor.black.withAlphaComponent(0.2).cgColor, UIColor.clear.cgColor]
        shade.startPoint = CGPoint(x: 0, y: 0)
        shade.endPoint = CGPoint(x: 1, y: 1)
        plate.addSublayer(reflection)
        plate.addSublayer(shade)
        reflection.opacity = 0
        shade.opacity = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        plate.bounds = bounds
        plate.position = CGPoint(x: bounds.midX, y: bounds.midY)
        plate.cornerRadius = bounds.height * 0.09
        reflection.frame = bounds.insetBy(dx: -bounds.width * 0.45, dy: -bounds.height * 0.35)
        shade.frame = bounds
        CATransaction.commit()
        render()
    }

    @objc private func handleContact(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            feedback.impactOccurred(intensity: 0.45)
            press(recognizer.location(in: self))
        case .changed:
            press(recognizer.location(in: self))
        case .ended, .cancelled, .failed:
            release()
        default: break
        }
    }

    private func press(_ point: CGPoint) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        physics.press(normalizedX: point.x / bounds.width * 2 - 1,
                      normalizedY: point.y / bounds.height * 2 - 1,
                      reducedMotion: reduceMotion)
        wake()
    }

    private func release() { physics.release(); wake() }

    private func wake() {
        guard window != nil, displayLink == nil else { return }
        lastTimestamp = 0
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        let dt = lastTimestamp == 0 ? link.targetTimestamp - link.timestamp : link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        physics.advance(seconds: dt)
        render()
        if physics.settled { stop() }
    }

    private func render() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 850
        transform = CATransform3DRotate(transform, physics.x, 1, 0, 0)
        transform = CATransform3DRotate(transform, physics.y, 0, 1, 0)
        plate.transform = transform
        // A broad anisotropic reflection follows the plate normal, never the finger itself.
        // Its zero opacity at rest preserves the supplied artwork's copper hue exactly.
        let energy = min(1, (abs(physics.x) + abs(physics.y)) / 0.18)
        reflection.opacity = Float(energy * 0.7)
        reflection.transform = CATransform3DMakeTranslation(physics.y * bounds.width * 2.5,
                                                            -physics.x * bounds.height * 2, 0)
        shade.opacity = Float(energy * 0.5)
        shade.startPoint = CGPoint(x: physics.y > 0 ? 1 : 0, y: physics.x < 0 ? 1 : 0)
        shade.endPoint = CGPoint(x: 0.5, y: 0.5)
        CATransaction.commit()
    }

    func stop() { displayLink?.invalidate(); displayLink = nil; lastTimestamp = 0 }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { stop(); physics = CardPhysics() }
    }
}

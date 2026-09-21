import Foundation

/// Selection is confirmed at the midpoint, never by release velocity. During a
/// flick only the neighboring stop is reachable; continued contact unlocks the
/// following stops without carrying any discarded motion or inertia forward.
struct CardSelectionDrag {
    static let sustainedContactDelay = 0.32
    private(set) var position: CGFloat = 0
    private(set) var selection = 0
    private var origin = 0
    private var previousTranslation: CGFloat = 0
    private var startedAt: Double = 0

    mutating func begin(selection: Int, at time: Double) {
        origin = selection
        self.selection = selection
        position = CGFloat(selection)
        previousTranslation = 0
        startedAt = time
    }

    mutating func update(translation: CGFloat, step: CGFloat, count: Int,
                         at time: Double) -> [Int] {
        guard step > 0, count > 0, translation.isFinite, time.isFinite else { return [] }
        let delta = (translation - previousTranslation) / step
        previousTranslation = translation
        let sustained = time - startedAt >= Self.sustainedContactDelay
        let lower = sustained ? 0 : max(origin - 1, 0)
        let upper = sustained ? count - 1 : min(origin + 1, count - 1)
        position = min(max(position + delta, CGFloat(lower)), CGFloat(upper))
        let next = Int(position.rounded())
        guard next != selection else { return [] }
        let direction = next > selection ? 1 : -1
        let crossings = Array(stride(from: selection + direction, through: next, by: direction))
        selection = next
        return crossings
    }
}

/// The native scroll view snaps at 52 pt. Its neighboring circles receive an
/// extra 4 pt of clearance around the stationary 48 pt selection ring (Figma).
enum CardColorRailMetrics {
    static let step: CGFloat = 52
    static func offset(index: Int, width: CGFloat) -> CGFloat {
        CGFloat(index) * step - (width / 2 - 20)
    }
    static func selection(offset: CGFloat, width: CGFloat, count: Int) -> Int {
        guard offset.isFinite, width.isFinite, count > 0 else { return 0 }
        let position = ((offset + width / 2 - 20) / step).rounded()
        return Int(min(max(position, 0), CGFloat(count - 1)))
    }
    static func clearance(distance: CGFloat) -> CGFloat {
        min(max(distance / step, -1), 1) * 4
    }
}
import CoreGraphics
import simd

/// A one-finger direction lock, measured in window coordinates so moving or
/// quarter-turning the card cannot feed its own displacement back into the drag.
struct CardPreviewDrag {
    enum Direction { case undecided, rotate, dismiss }
    private(set) var direction = Direction.undecided
    private(set) var translation: CGFloat = 0
    private var origin = CGPoint.zero

    mutating func begin(x: CGFloat, y: CGFloat) {
        origin = CGPoint(x: x, y: y)
        direction = .undecided
        translation = 0
    }

    mutating func update(x: CGFloat, y: CGFloat) {
        let dx = x - origin.x, dy = y - origin.y
        if direction == .undecided, max(abs(dx), abs(dy)) >= 8 {
            direction = dy > abs(dx) * 1.15 ? .dismiss : .rotate
        }
        if direction == .dismiss { translation = max(0, dy) }
    }

    static func shouldDismiss(translation: CGFloat, cardHeight: CGFloat,
                              centerY: CGFloat, viewportHeight: CGFloat) -> Bool {
        guard translation > 0, cardHeight > 0, viewportHeight > 0,
              translation.isFinite, cardHeight.isFinite,
              centerY.isFinite, viewportHeight.isFinite else { return false }
        // Measure the portion beyond the viewport, not the finger's travel.
        let hiddenHeight = centerY + translation + cardHeight / 2 - viewportHeight
        return hiddenHeight >= cardHeight * 0.25
    }
}

/// One finger controls screen yaw. A two-finger gesture behaves like a photo:
/// pinch to scale, move the centroid to pan and twist to roll, without accidental
/// pitch/yaw caused by the two fingers moving by slightly different amounts.
/// A one-finger release holds the exact orientation for three seconds, then returns
/// to the front in 600 ms. A released photo transform can request an immediate
/// coordinated return with zoom. Its clock is injected for deterministic tests.
struct CardPhysics {
    static let previewEntranceDuration = 0.72
    static let previewSettleDuration = 0.24
    static let returnDelay = 3.0
    static let returnDuration = 0.6
    private static let identity = simd_quatd(angle: 0, axis: SIMD3<Double>(0, 1, 0))
    private var rotation = identity
    private var lastX: Double?
    private var gestureWidth = 1.0
    private var freeStartPoint: SIMD2<Double>?
    private var freeGestureSize = SIMD2<Double>(repeating: 1)
    private var freeStartRotation = identity
    private var returning: (start: Double, from: simd_quatd, duration: Double)?
    private var entranceStart: Double?

    var orientation: simd_quatf {
        simd_quatf(ix: Float(rotation.imag.x), iy: Float(rotation.imag.y),
                   iz: Float(rotation.imag.z), r: Float(rotation.real))
    }
    var isDragging: Bool { lastX != nil || freeStartPoint != nil }
    var returnStartTime: Double? { returning?.start }
    var hasAutomaticReturn: Bool { returning != nil }
    var isEnteringPreview: Bool { entranceStart != nil }

    /// Preserve the original enlargement/rotation arc, then give the card one
    /// small opposite rock. Both lobes meet at zero velocity; no endless spring.
    mutating func beginPreviewEntrance(at time: Double) {
        guard time.isFinite else { return }
        reset()
        entranceStart = time
    }

    mutating func begin(x: Double, y: Double, width: Double, height: Double, at time: Double) {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite,
              width > 0, height > 0, time.isFinite else { return }
        interruptAutomaticReturn(at: time)
        lastX = x
        freeStartPoint = nil
        gestureWidth = width
    }

    mutating func update(x: Double, y: Double) {
        guard let previous = lastX, x.isFinite, y.isFinite else { return }
        let increment = (x - previous) / gestureWidth * .pi
        guard increment.isFinite else { return }
        lastX = x
        // Y input is intentionally ignored. Rightward screen movement turns the
        // front surface right around +Y; one screen card width gives 180 degrees.
        let yaw = simd_quatd(angle: increment, axis: SIMD3<Double>(0, 1, 0))
        rotation = simd_normalize(yaw * rotation)
    }

    /// Begins an absolute two-finger gesture. Translation of the centroid maps
    /// to screen pitch/yaw while the angle between the fingers maps to screen roll.
    mutating func beginFree(x: Double, y: Double, width: Double, height: Double, at time: Double) {
        guard x.isFinite, y.isFinite, width.isFinite, height.isFinite,
              width > 0, height > 0, time.isFinite else { return }
        interruptAutomaticReturn(at: time)
        lastX = nil
        freeStartPoint = SIMD2(x, y)
        freeGestureSize = SIMD2(width, height)
        freeStartRotation = rotation
    }

    mutating func updateFree(x: Double, y: Double, roll: Double) {
        guard let start = freeStartPoint, x.isFinite, y.isFinite, roll.isFinite else { return }
        let delta = (SIMD2(x, y) - start) / freeGestureSize
        guard delta.x.isFinite, delta.y.isFinite else { return }
        let yaw = simd_quatd(angle: delta.x * .pi, axis: SIMD3<Double>(0, 1, 0))
        let pitch = simd_quatd(angle: delta.y * .pi, axis: SIMD3<Double>(1, 0, 0))
        let twist = simd_quatd(angle: roll, axis: SIMD3<Double>(0, 0, 1))
        rotation = simd_normalize(twist * pitch * yaw * freeStartRotation)
    }

    /// Starts a photo-like two-finger transform. Translation belongs to `CardZoom`;
    /// only the actual angle between the fingers changes orientation here.
    mutating func beginPhotoTransform(at time: Double) {
        guard time.isFinite else { return }
        interruptAutomaticReturn(at: time)
        lastX = nil
        freeStartPoint = .zero
        freeStartRotation = rotation
    }

    mutating func updatePhotoTransform(roll: Double) {
        guard freeStartPoint != nil, roll.isFinite else { return }
        // UIKit angles grow clockwise because screen Y points down. Scene space uses Y up.
        let twist = simd_quatd(angle: -roll, axis: SIMD3<Double>(0, 0, 1))
        rotation = simd_normalize(twist * freeStartRotation)
    }

    mutating func end(at time: Double, scheduleReturn: Bool = true) {
        lastX = nil
        freeStartPoint = nil
        if scheduleReturn { scheduleAutomaticReturn(at: time) }
    }

    mutating func scheduleAutomaticReturn(at time: Double) {
        guard time.isFinite else { return }
        let distance = min(simd_length(rotation.vector - Self.identity.vector),
                           simd_length(rotation.vector + Self.identity.vector))
        guard distance > 0.0000001 else {
            rotation = Self.identity
            returning = nil
            return
        }
        returning = (time + Self.returnDelay, rotation, Self.returnDuration)
    }

    /// Returns every orientation axis to the front immediately over the supplied duration.
    /// This is used when a two-finger photo gesture ends so rotation, pan and scale settle together.
    mutating func returnToDefault(at time: Double, duration: Double) {
        guard time.isFinite, duration.isFinite, duration > 0 else { return }
        lastX = nil
        freeStartPoint = nil
        let distance = min(simd_length(rotation.vector - Self.identity.vector),
                           simd_length(rotation.vector + Self.identity.vector))
        guard distance > 0.0000001 else {
            rotation = Self.identity
            returning = nil
            return
        }
        returning = (time, rotation, duration)
    }

    /// Call for any new gesture, including the first contact before a pinch is
    /// recognized. Interrupting an in-flight return retains its presented angle.
    mutating func interruptAutomaticReturn(at time: Double) {
        advance(at: time)
        returning = nil
        entranceStart = nil
    }

    mutating func advance(at time: Double) {
        if let start = entranceStart, time.isFinite {
            let elapsed = max(time - start, 0)
            let p = min(elapsed / Self.previewEntranceDuration, 1)
            let q = min(max((elapsed - Self.previewEntranceDuration) / Self.previewSettleDuration, 0), 1)
            // 28°/−12° original turn; the follow-through is only −3°/+1.3°.
            let arc = 16 * p * p * (1 - p) * (1 - p)
                - (3.0 / 28) * 16 * q * q * (1 - q) * (1 - q)
            let yaw = simd_quatd(angle: arc * 28 * .pi / 180, axis: SIMD3(0, 1, 0))
            let pitch = simd_quatd(angle: -arc * 12 * .pi / 180, axis: SIMD3(1, 0, 0))
            rotation = simd_normalize(pitch * yaw)
            if q >= 1 { rotation = Self.identity; entranceStart = nil }
        }
        guard let state = returning, time.isFinite, time >= state.start else { return }
        let progress = min((time - state.start) / state.duration, 1)
        let eased = progress * progress * (3 - 2 * progress)
        rotation = simd_normalize(simd_slerp(state.from, Self.identity, eased))
        if progress >= 1 { rotation = Self.identity; returning = nil }
    }

    mutating func reset() {
        rotation = Self.identity
        lastX = nil
        freeStartPoint = nil
        returning = nil
        entranceStart = nil
    }
}

/// Uniform 3D magnification around a card-local point. The current orientation
/// is supplied on every update so the same physical point remains under the
/// two-finger centroid while the card rotates and scales at once.
struct CardZoom {
    static let returnDuration = 0.3
    static let maximumScale = 3.0
    private(set) var scale = 1.0
    private(set) var translation = SIMD3<Double>.zero
    private(set) var isPinching = false
    private var initialScale = 1.0
    private var localAnchor = SIMD3<Double>.zero
    private var returning: (start: Double, scale: Double, translation: SIMD3<Double>)?
    var isReturning: Bool { returning != nil }

    mutating func begin(localAnchor: SIMD3<Double>, at time: Double) {
        interruptReturn(at: time)
        self.localAnchor = localAnchor
        initialScale = scale
        isPinching = true
    }

    mutating func update(factor: Double, worldFocus: SIMD3<Double>, orientation: simd_quatd) {
        guard isPinching, factor.isFinite, factor > 0,
              worldFocus.x.isFinite, worldFocus.y.isFinite, worldFocus.z.isFinite,
              orientation.vector.x.isFinite, orientation.vector.y.isFinite,
              orientation.vector.z.isFinite, orientation.vector.w.isFinite else { return }
        scale = min(max(initialScale * factor, 1), Self.maximumScale)
        translation = worldFocus - orientation.act(localAnchor) * scale
    }

    mutating func end(at time: Double) {
        isPinching = false
        guard abs(scale - 1) > 0.0000001 || simd_length(translation) > 0.0000001 else {
            returning = nil
            return
        }
        returning = (time, scale, translation)
    }

    mutating func interruptReturn(at time: Double) {
        advance(at: time)
        returning = nil
    }

    mutating func advance(at time: Double) {
        guard let state = returning, time.isFinite else { return }
        let progress = min(max((time - state.start) / Self.returnDuration, 0), 1)
        let eased = progress * progress * (3 - 2 * progress)
        scale = state.scale + (1 - state.scale) * eased
        translation = state.translation * (1 - eased)
        if progress >= 1 { scale = 1; translation = .zero; returning = nil }
    }

    mutating func reset() {
        scale = 1
        translation = .zero
        isPinching = false
        returning = nil
    }
}

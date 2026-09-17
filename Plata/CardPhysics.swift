import Foundation
import simd

/// One finger controls screen yaw. Two fingers can additionally pitch and roll
/// the card while zooming. Release holds the exact orientation for three seconds,
/// then returns to the front in 600 ms. Its clock is injected for deterministic tests.
struct CardPhysics {
    static let returnDelay = 3.0
    static let returnDuration = 0.6
    private static let identity = simd_quatd(angle: 0, axis: SIMD3<Double>(0, 1, 0))
    private var rotation = identity
    private var lastX: Double?
    private var gestureWidth = 1.0
    private var freeStartPoint: SIMD2<Double>?
    private var freeGestureSize = SIMD2<Double>(repeating: 1)
    private var freeStartRotation = identity
    private var returning: (start: Double, from: simd_quatd)?

    var orientation: simd_quatf {
        simd_quatf(ix: Float(rotation.imag.x), iy: Float(rotation.imag.y),
                   iz: Float(rotation.imag.z), r: Float(rotation.real))
    }
    var isDragging: Bool { lastX != nil || freeStartPoint != nil }
    var returnStartTime: Double? { returning?.start }
    var hasAutomaticReturn: Bool { returning != nil }

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
        returning = (time + Self.returnDelay, rotation)
    }

    /// Call for any new gesture, including the first contact before a pinch is
    /// recognized. Interrupting an in-flight return retains its presented angle.
    mutating func interruptAutomaticReturn(at time: Double) {
        advance(at: time)
        returning = nil
    }

    mutating func advance(at time: Double) {
        guard let state = returning, time.isFinite, time >= state.start else { return }
        let progress = min((time - state.start) / Self.returnDuration, 1)
        let eased = progress * progress * (3 - 2 * progress)
        rotation = simd_normalize(simd_slerp(state.from, Self.identity, eased))
        if progress >= 1 { rotation = Self.identity; returning = nil }
    }

    mutating func reset() {
        rotation = Self.identity
        lastX = nil
        freeStartPoint = nil
        returning = nil
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

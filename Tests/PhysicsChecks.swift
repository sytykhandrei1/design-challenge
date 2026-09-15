import Foundation

@main
struct PhysicsChecks {
    static func main() {
        var spring = CardPhysics()
        spring.press(normalizedX: 1, normalizedY: 1, reducedMotion: false)
        precondition(spring.targetX < 0 && spring.targetY > 0, "Touched lower-right edge must move away")
        for _ in 0..<120 { spring.advance(seconds: 1.0 / 120) }
        precondition(abs(spring.x + 0.16) < 0.001 && abs(spring.y - 0.16) < 0.001)
        spring.release()
        for _ in 0..<240 { spring.advance(seconds: 1.0 / 120) }
        precondition(spring.settled && abs(spring.x) < 0.0001 && abs(spring.y) < 0.0001)
        var sixty = CardPhysics(), oneTwenty = CardPhysics()
        sixty.press(normalizedX: -1, normalizedY: 0.5, reducedMotion: false)
        oneTwenty = sixty
        for _ in 0..<30 { sixty.advance(seconds: 1.0 / 60) }
        for _ in 0..<60 { oneTwenty.advance(seconds: 1.0 / 120) }
        precondition(abs(sixty.x - oneTwenty.x) < 0.0001 && abs(sixty.y - oneTwenty.y) < 0.0001)
        sixty.advance(seconds: 4)
        precondition(sixty.x.isFinite && sixty.y.isFinite)
        sixty.press(normalizedX: 5, normalizedY: -5, reducedMotion: true)
        precondition(abs(sixty.targetX) <= 0.025 && abs(sixty.targetY) <= 0.025)
        print("PASS: torque direction, equilibrium, release, 60/120 Hz, frame interruption, Reduce Motion")
    }
}

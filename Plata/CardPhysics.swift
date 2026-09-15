import Foundation

/// A rigid plate supported at its centre. Each axis follows a damped torsional spring.
struct CardPhysics {
    var x = 0.0
    var y = 0.0
    var velocityX = 0.0
    var velocityY = 0.0
    var targetX = 0.0
    var targetY = 0.0

    mutating func press(normalizedX: Double, normalizedY: Double, reducedMotion: Bool) {
        let limit = reducedMotion ? 0.025 : 0.16
        // UIKit y points down; these signs push the touched edge away from the viewer.
        targetX = -min(max(normalizedY, -1), 1) * limit
        targetY = min(max(normalizedX, -1), 1) * limit
    }

    mutating func release() { targetX = 0; targetY = 0 }

    mutating func advance(seconds: Double) {
        // Substeps keep the spring stable across 60/120 Hz and interrupted frames.
        let dt = min(max(seconds, 0), 1.0 / 15)
        let steps = max(1, Int(ceil(dt / (1.0 / 240))))
        let h = dt / Double(steps)
        for _ in 0..<steps {
            // Different plate moments of inertia: long axis settles more slowly.
            velocityX += ((targetX - x) * 240 - velocityX * 25) * h
            velocityY += ((targetY - y) * 180 - velocityY * 22) * h
            x += velocityX * h
            y += velocityY * h
        }
    }

    var settled: Bool {
        abs(x - targetX) + abs(y - targetY) < 0.0001 && abs(velocityX) + abs(velocityY) < 0.001
    }
}

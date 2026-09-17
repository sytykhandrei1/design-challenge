import Foundation
import simd

@main
struct PhysicsChecks {
    static let identity = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    static let normal = SIMD3<Float>(0, 0, 1)

    static func sameRotation(_ lhs: simd_quatf, _ rhs: simd_quatf, _ message: String) {
        let distance = min(simd_length(lhs.vector - rhs.vector), simd_length(lhs.vector + rhs.vector))
        precondition(distance < 0.00001, message)
    }
    static func near(_ actual: Double, _ expected: Double, _ message: String) {
        precondition(abs(actual - expected) < 0.000001, message)
    }
    static func near(_ actual: SIMD3<Double>, _ expected: SIMD3<Double>, _ message: String) {
        precondition(simd_length(actual - expected) < 0.000001, message)
    }
    static func near(_ actual: SIMD3<Float>, _ expected: SIMD3<Float>, _ message: String) {
        precondition(simd_length(actual - expected) < 0.00001, message)
    }
    static func front(_ card: CardPhysics) { sameRotation(card.orientation, identity, "Expected front orientation") }

    static func main() {
        var card = CardPhysics()
        card.begin(x: 37, y: 82, width: 320, height: 200, at: 0)
        card.update(x: 37, y: 82)
        card.end(at: 1)
        front(card)
        precondition(!card.hasAutomaticReturn, "An unchanged front has no background animation")

        card.begin(x: 0, y: 0, width: 320, height: 200, at: 2)
        card.update(x: 0, y: 1000)
        front(card)
        card.update(x: 3.2, y: -1000)
        sameRotation(card.orientation, simd_quatf(angle: .pi / 100, axis: SIMD3(0, 1, 0)),
                     "Only horizontal movement controls angle")
        card.update(x: 160, y: 500)
        sameRotation(card.orientation, simd_quatf(angle: .pi / 2, axis: SIMD3(0, 1, 0)),
                     "Half a card width exposes the edge")
        card.update(x: 320, y: 500)
        sameRotation(card.orientation, simd_quatf(angle: .pi, axis: SIMD3(0, 1, 0)), "One width shows the back")
        card.end(at: 10)
        near(card.returnStartTime!, 13, "The return deadline is exactly three seconds after release")
        card.advance(at: 12.999999)
        sameRotation(card.orientation, simd_quatf(angle: .pi, axis: SIMD3(0, 1, 0)),
                     "No return may occur before the deadline")
        card.advance(at: 13)
        sameRotation(card.orientation, simd_quatf(angle: .pi, axis: SIMD3(0, 1, 0)),
                     "At the deadline the animation starts without a jump")
        card.advance(at: 13.3)
        let halfwayNormal = card.orientation.act(normal)
        precondition(abs(abs(halfwayNormal.x) - 1) < 0.00001 && abs(halfwayNormal.z) < 0.00001,
                     "Halfway through 600ms, the eased orientation exposes an edge")
        card.advance(at: 13.601)
        front(card)
        precondition(!card.hasAutomaticReturn, "Return stops its animation when complete")

        card.begin(x: 0, y: 0, width: 320, height: 200, at: 20)
        card.update(x: 80, y: 0)
        card.end(at: 21)
        card.interruptAutomaticReturn(at: 23.99)
        card.advance(at: 100)
        sameRotation(card.orientation, simd_quatf(angle: .pi / 4, axis: SIMD3(0, 1, 0)),
                     "New contact cancels a pending return")
        card.begin(x: 111, y: 70, width: 320, height: 200, at: 100)
        sameRotation(card.orientation, simd_quatf(angle: .pi / 4, axis: SIMD3(0, 1, 0)),
                     "Regrab does not jump")
        card.update(x: 151, y: -400)
        sameRotation(card.orientation, simd_quatf(angle: .pi * 3 / 8, axis: SIMD3(0, 1, 0)),
                     "Regrab continues proportionally and ignores vertical movement")
        card.update(x: 111, y: 500)
        sameRotation(card.orientation, simd_quatf(angle: .pi / 4, axis: SIMD3(0, 1, 0)),
                     "Horizontal reversal retraces the angle")
        card.end(at: 101)
        card.begin(x: 50, y: 0, width: 320, height: 200, at: 104.3)
        sameRotation(card.orientation, simd_quatf(angle: .pi / 8, axis: SIMD3(0, 1, 0)),
                     "A gesture interrupts an active return at its visible angle")
        card.advance(at: 105)
        sameRotation(card.orientation, simd_quatf(angle: .pi / 8, axis: SIMD3(0, 1, 0)),
                     "An interrupted return cannot continue behind the finger")

        card.reset()
        card.begin(x: 0, y: 0, width: 320, height: 200, at: 0)
        card.update(x: 2480, y: 99)
        sameRotation(card.orientation, simd_quatf(angle: .pi * 7.75, axis: SIMD3(0, 1, 0)),
                     "Complete turns remain continuous")
        card.end(at: 1)
        card.advance(at: 4.3)
        sameRotation(card.orientation, simd_quatf(angle: .pi * 7.875, axis: SIMD3(0, 1, 0)),
                     "Reset uses the nearest front instead of undoing all complete turns")
        card.advance(at: 4.601)
        front(card)

        var coarse = CardPhysics(), fine = CardPhysics()
        coarse.begin(x: 0, y: 0, width: 320, height: 200, at: 0)
        fine.begin(x: 0, y: 0, width: 640, height: 400, at: 0)
        coarse.update(x: 96, y: 40)
        for step in 1...120 { fine.update(x: 192 * Double(step) / 120, y: Double(step) * 30) }
        sameRotation(coarse.orientation, fine.orientation, "Event rate and view size do not alter sensitivity")
        let valid = fine.orientation
        fine.update(x: .nan, y: 40)
        fine.update(x: .infinity, y: 40)
        sameRotation(fine.orientation, valid, "Invalid input cannot corrupt orientation")

        // The external clockwise SwiftUI quarter-turn must still present yaw
        // around screen Y. A rightward drag moves the front normal to the right.
        let basis = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 0, 1))
        let external = basis.inverse
        let local = basis * coarse.orientation * basis.inverse
        let screenNormal = external.act(local.act(normal))
        precondition(screenNormal.x > 0 && abs(screenNormal.y) < 0.000001,
                     "Screen-horizontal dragging must not introduce vertical tilt")

        // Two fingers control all three screen-space rotation axes. A quarter
        // twist rotates the card's long edge from horizontal to vertical.
        card.reset()
        card.beginFree(x: 100, y: 100, width: 200, height: 200, at: 0)
        card.updateFree(x: 100, y: 100, roll: .pi / 2)
        near(card.orientation.act(SIMD3(1, 0, 0)), SIMD3(0, 1, 0),
             "Two-finger twist must rotate the card in-plane to horizontal/vertical layouts")
        card.reset()
        card.beginFree(x: 100, y: 100, width: 200, height: 200, at: 0)
        card.updateFree(x: 150, y: 150, roll: .pi / 4)
        let freelyRotated = card.orientation
        precondition(abs(freelyRotated.imag.x) > 0.01 && abs(freelyRotated.imag.y) > 0.01 &&
                     abs(freelyRotated.imag.z) > 0.01,
                     "Two-finger centroid and twist must combine pitch, yaw and roll")
        card.end(at: 1)
        card.advance(at: 4.3)
        precondition(simd_length(card.orientation.vector - freelyRotated.vector) > 0.01,
                     "Free orientation must animate back during the 600ms return")
        card.advance(at: 4.601)
        front(card)

        // Test a focus off-centre and away from the object's centre-depth, as on
        // a tilted face. It stays pinned while orientation and scale both change.
        var zoom = CardZoom()
        let anchor = SIMD3<Double>(18, -9, 14)
        let zoomOrientation = simd_quatd(angle: .pi / 3, axis: simd_normalize(SIMD3<Double>(1, 1, 0.5)))
        let rotatedAnchor = zoomOrientation.act(anchor)
        zoom.begin(localAnchor: anchor, at: 0)
        zoom.update(factor: 2, worldFocus: rotatedAnchor, orientation: zoomOrientation)
        near(zoom.scale, 2, "Pinch scale tracks finger separation")
        near(zoom.translation + zoomOrientation.act(anchor) * zoom.scale, rotatedAnchor,
             "Off-centre focus remains fixed while the card rotates")
        let movedFocus = SIMD3<Double>(26, -3, 14)
        let movedOrientation = simd_quatd(angle: .pi / 2, axis: simd_normalize(SIMD3<Double>(1, -0.5, 1)))
        zoom.update(factor: 2.4, worldFocus: movedFocus, orientation: movedOrientation)
        near(zoom.translation + movedOrientation.act(anchor) * zoom.scale, movedFocus,
             "The same area follows a moving centroid during free rotation")
        precondition(abs(zoom.translation.z) > 0, "Tilted anchoring must include depth translation")
        zoom.update(factor: 10, worldFocus: movedFocus, orientation: movedOrientation)
        near(zoom.scale, 3, "Zoom has a bounded maximum")
        near(zoom.translation + movedOrientation.act(anchor) * zoom.scale, movedFocus,
             "Focus remains pinned at the scale limit")
        zoom.end(at: 5)
        zoom.advance(at: 5.15)
        near(zoom.scale, 2, "Release smoothly returns zoom toward 100%")
        let partialScale = zoom.scale
        let partialTranslation = zoom.translation
        zoom.interruptReturn(at: 5.15)
        zoom.begin(localAnchor: anchor, at: 5.15)
        zoom.update(factor: 1,
                    worldFocus: partialTranslation + movedOrientation.act(anchor) * partialScale,
                    orientation: movedOrientation)
        near(zoom.scale, partialScale, "New pinch starts at the visible scale")
        near(zoom.translation, partialTranslation, "New pinch keeps the visible focus without a jump")
        zoom.end(at: 6)
        zoom.advance(at: 6.301)
        near(zoom.scale, 1, "Zoom returns exactly to 100%")
        near(zoom.translation, .zero, "Zoom return restores the original position")
        precondition(!zoom.isReturning && !zoom.isPinching)

        print("PASS: one-finger Y-only yaw, two-finger free pitch/yaw/roll, horizontal layout, anchored simultaneous zoom, 3s deadline, 600ms return, cancellation, regrab, full turns, event rate, zoom limits and reset")
    }
}

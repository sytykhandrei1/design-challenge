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

    static func checkPreviewInertia() {
        func stroke(direction: Double, duration: Double, hold: Double = 0) -> CardPhysics {
            var card = CardPhysics()
            card.begin(x: 0, y: 0, width: 300, height: 500, at: 0,
                       response: CardPhysics.previewDragResponse)
            for step in 1...20 {
                card.update(x: direction * 60 * Double(step) / 20, y: 0,
                            at: duration * Double(step) / 20)
            }
            let released = card.orientation
            card.endWithInertia(at: duration + hold)
            card.advance(at: duration + hold)
            sameRotation(card.orientation, released, "No orientation jump on release")
            precondition(!card.isDragging)
            return card
        }
        func measure(_ input: CardPhysics, start: Double, direction: Double, fps: Int) -> (Double, Double) {
            var card = input
            var previous = atan2(Double(card.orientation.act(normal).x), Double(card.orientation.act(normal).z))
            var distance = 0.0
            var priorSpeed = CardPhysics.maximumCoastSpeed
            for tick in 1...fps * 15 {
                card.advance(at: start + Double(tick) / Double(fps))
                let face = card.orientation.act(normal)
                let angle = atan2(Double(face.x), Double(face.z))
                var delta = angle - previous
                if delta > .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                let speed = direction * delta * Double(fps)
                precondition(speed >= -0.0001, "Never reverse toward the shortest path")
                precondition(speed <= CardPhysics.maximumCoastSpeed + 0.001, "Even strongest flick is speed limited")
                precondition(speed <= priorSpeed + 0.001, "Coast slows down monotonically")
                priorSpeed = speed
                distance += direction * delta
                previous = angle
                if !card.isCoasting {
                    front(card)
                    precondition(!card.hasAutomaticReturn)
                    return (distance, Double(tick) / Double(fps))
                }
            }
            preconditionFailure("Coast must finish, never loop")
        }
        for direction in [-1.0, 1.0] {
            for input in [stroke(direction: direction, duration: 0.7),
                          stroke(direction: direction, duration: 0.055, hold: 0.5)] {
                var held = input
                let released = held.orientation
                precondition(!held.hasAutomaticReturn, "Gentle or held releases must not move automatically")
                held.advance(at: 30)
                sameRotation(held.orientation, released, "Weak rotation stays at the exact released pose")
            }
            let medium = stroke(direction: direction, duration: 0.14)
            let strong = stroke(direction: direction, duration: 0.055)
            precondition(medium.isCoasting && strong.isCoasting)
            let a = measure(medium, start: 0.14, direction: direction, fps: 120)
            let b = measure(strong, start: 0.055, direction: direction, fps: 120)
            precondition(abs(a.0 + 0.1 * .pi - 2 * .pi) < 0.0001, "Half-speed drag plus coast completes exactly one turn")
            precondition(abs(b.0 - a.0) < 0.0001 && b.1 < a.1,
                         "Strong stroke reaches the SAME front sooner, without an extra turn")
            let coarse = measure(strong, start: 0.055, direction: direction, fps: 30)
            precondition(abs(coarse.0 - b.0) < 0.0001, "Travel is frame-rate independent")
            var interrupted = strong
            interrupted.advance(at: 0.8)
            let visible = interrupted.orientation
            interrupted.begin(x: 10, y: 0, width: 300, height: 500, at: 0.8)
            sameRotation(interrupted.orientation, visible, "Regrab retains the exact presented pose")
            interrupted.advance(at: 20)
            sameRotation(interrupted.orientation, visible, "Touch stops the coast immediately")
            precondition(!interrupted.isCoasting)
            interrupted.beginPhotoTransform(at: 20)
            interrupted.returnToDefault(at: 20, duration: 0.3)
            interrupted.advance(at: 20.31)
            front(interrupted)
        }
        var tap = CardPhysics()
        tap.begin(x: 0, y: 0, width: 300, height: 500, at: 0)
        tap.endWithInertia(at: 1)
        precondition(!tap.isCoasting, "A stationary tap never spins")
        var reversal = stroke(direction: 1, duration: 0.7)
        reversal.begin(x: 100, y: 0, width: 300, height: 500, at: 0.7)
        reversal.update(x: 120, y: 0, at: 0.8)
        reversal.update(x: 60, y: 0, at: 0.85)
        reversal.endWithInertia(at: 0.85)
        _ = measure(reversal, start: 0.85, direction: -1, fps: 60)
        for direction in [-1.0, 1.0] {
            for turns in [0.01, 0.49, 0.51, 0.99, 1.2, 2.7] {
                var card = CardPhysics()
                card.begin(x: 0, y: 0, width: 300, height: 500, at: 0,
                           response: CardPhysics.previewDragResponse)
                card.update(x: direction * (turns * 1200 - 60), y: 0, at: 0.01)
                card.update(x: direction * turns * 1200, y: 0, at: 0.065)
                card.endWithInertia(at: 0.065)
                precondition(card.isCoasting)
                let result = measure(card, start: 0.065, direction: direction, fps: 60)
                precondition(abs(result.0 - (ceil(turns) - turns) * 2 * .pi) < 0.0001,
                             "Always stop on the first front in the stroke direction")
            }
            var completed = CardPhysics()
            completed.begin(x: 0, y: 0, width: 300, height: 500, at: 0,
                            response: CardPhysics.previewDragResponse)
            completed.update(x: direction * 1200, y: 0, at: 1)
            completed.endWithInertia(at: 1)
            precondition(!completed.isCoasting, "A completed turn must not launch another")
            front(completed)
        }
        near(CardPhysics.minimumCoastSpeed, 1.8, "Minimum coast speed is doubled")
        near(CardPhysics.maximumCoastSpeed, 2.8, "Maximum coast speed is doubled")
        print("PASS: weak/held release stays still, strong flick only, weighted drag, first-front stop, stronger=faster, 30/120Hz, reversal, regrab and pinch takeover")
    }

    static func main() {
        checkPreviewInertia()
        var entrance = CardPhysics()
        entrance.beginPreviewEntrance(at: 10)
        front(entrance)
        var previousAngle: Float = 0
        for tick in 0...120 {
            let p = Double(tick) / 120
            entrance.advance(at: 10 + p * CardPhysics.previewEntranceDuration)
            let angle = entrance.orientation.angle
            precondition(angle.isFinite && angle < 32 * .pi / 180)
            if tick <= 60 { precondition(angle + 0.00001 >= previousAngle) }
            else { precondition(angle <= previousAngle + 0.00001, "The original enlargement arc is unchanged") }
            previousAngle = angle
        }
        entrance.advance(at: 10 + CardPhysics.previewEntranceDuration + CardPhysics.previewSettleDuration / 2)
        precondition(entrance.isEnteringPreview)
        precondition(entrance.orientation.act(normal).x < 0, "The small follow-through rocks in the opposite direction")
        precondition(entrance.orientation.angle > 2 * .pi / 180 && entrance.orientation.angle < 4 * .pi / 180,
                     "One restrained 3D bounce, not another large turn")
        entrance.advance(at: 10 + CardPhysics.previewEntranceDuration + CardPhysics.previewSettleDuration + 0.001)
        front(entrance)
        precondition(!entrance.isEnteringPreview)
        entrance.advance(at: 11)
        front(entrance)
        precondition(!entrance.isEnteringPreview)
        entrance.beginPreviewEntrance(at: 20)
        entrance.advance(at: 20.25)
        let touchedPose = entrance.orientation
        entrance.begin(x: 100, y: 100, width: 300, height: 500, at: 20.25)
        sameRotation(entrance.orientation, touchedPose, "Touch must take over without a pose jump")
        entrance.advance(at: 21)
        sameRotation(entrance.orientation, touchedPose, "Touch cancels the entrance animation")
        entrance.reset()
        front(entrance)

        var rail = CardSelectionDrag()
        near(Double(CardTypePaging.dragStep(362)), 224.44, "Types commit at 112pt rather than 181pt")
        precondition(CardTypePaging.releaseSelection(position: 0.2, selection: 0, translation: 45,
                     predictedExtra: 100, pageWidth: 362, count: 2) == 1, "Short forward flick is completed")
        precondition(CardTypePaging.releaseSelection(position: 0.8, selection: 1, translation: -45,
                     predictedExtra: -100, pageWidth: 362, count: 2) == 0, "Short reverse flick is completed")
        precondition(CardTypePaging.releaseSelection(position: 0.2, selection: 0, translation: 45,
                     predictedExtra: 0, pageWidth: 362, count: 2) == 0, "Slow incomplete drag still cancels")
        precondition(CardTypePaging.releaseSelection(position: 0.05, selection: 0, translation: 8,
                     predictedExtra: 200, pageWidth: 362, count: 2) == 0, "Touch jitter is not a flick")
        precondition(CardTypePaging.releaseSelection(position: 1, selection: 1, translation: 600,
                     predictedExtra: 900, pageWidth: 362, count: 2) == 1, "An outward flick cannot bounce to the other type")
        rail.begin(selection: 0, at: 0)
        precondition(rail.update(translation: 25.9, step: 52, count: 6, at: 0.1).isEmpty)
        precondition(rail.selection == 0, "Before midpoint, release must return to the old card")
        precondition(rail.update(translation: 26.1, step: 52, count: 6, at: 0.12) == [1])
        precondition(rail.update(translation: 25.9, step: 52, count: 6, at: 0.14) == [0])
        precondition(rail.update(translation: 26.1, step: 52, count: 6, at: 0.16) == [1],
                     "Crossing the same midpoint in either direction emits a new haptic")
        precondition(rail.update(translation: 600, step: 52, count: 6, at: 0.2).isEmpty)
        precondition(rail.selection == 1 && rail.position == 1, "A fast full-width flick advances one stop only")
        precondition(rail.update(translation: 600, step: 52, count: 6, at: 0.6).isEmpty,
                     "Holding still must not consume discarded flick distance")
        precondition(rail.update(translation: 704, step: 52, count: 6, at: 0.9) == [2, 3],
                     "Continuing the same held gesture visits every neighbor in order")
        precondition(rail.update(translation: 599, step: 52, count: 6, at: 1.1) == [2, 1])
        rail.begin(selection: 5, at: 2)
        precondition(rail.update(translation: -600, step: 52, count: 6, at: 2.1) == [4])
        precondition(rail.selection == 4, "Reverse flick also advances just one")
        rail.begin(selection: 0, at: 3)
        precondition(rail.update(translation: 180, step: 362, count: 2, at: 3.1).isEmpty)
        precondition(rail.update(translation: 182, step: 362, count: 2, at: 3.2) == [1])
        precondition(rail.update(translation: 180, step: 362, count: 2, at: 3.3) == [0])

        for width: CGFloat in [320, 375, 393, 402, 440] {
            for count in [2, 5, 6] {
                for index in 0..<count {
                    let offset = CardColorRailMetrics.offset(index: index, width: width)
                    precondition(CardColorRailMetrics.selection(offset: offset, width: width, count: count) == index)
                    near(Double(CGFloat(index) * 52 + 20 - offset), Double(width / 2),
                         "Every finish aligns to the stationary center on every device width")
                }
                precondition(CardColorRailMetrics.selection(offset: -10000, width: width, count: count) == 0)
                precondition(CardColorRailMetrics.selection(offset: 10000, width: width, count: count) == count - 1)
            }
        }
        near(Double(CardColorRailMetrics.clearance(distance: 0)), 0, "Selected circle stays centered")
        near(Double(52 + CardColorRailMetrics.clearance(distance: 52)), 56, "First neighbor matches Figma")
        near(Double(104 + CardColorRailMetrics.clearance(distance: 104)), 108, "Following circles retain 12 pt gaps")
        near(Double(-52 + CardColorRailMetrics.clearance(distance: -52)), -56, "Clearance is symmetric")

        var dismissal = CardPreviewDrag()
        dismissal.begin(x: 100, y: 100)
        dismissal.update(x: 102, y: 105)
        precondition(dismissal.direction == .undecided, "Ignore touch jitter")
        dismissal.update(x: 102, y: 120)
        precondition(dismissal.direction == .dismiss)
        near(Double(dismissal.translation), 20, "Downward travel follows the finger 1:1")
        dismissal.update(x: 200, y: 90)
        precondition(dismissal.direction == .dismiss, "Direction remains locked")
        near(Double(dismissal.translation), 0, "Never move the card above its resting pose")
        dismissal.begin(x: 100, y: 100)
        dismissal.update(x: 120, y: 102)
        dismissal.update(x: 120, y: 400)
        precondition(dismissal.direction == .rotate, "A rotating gesture cannot accidentally dismiss")
        for (height, center, viewport): (CGFloat, CGFloat, CGFloat) in
            [(530, 310, 650), (440, 280, 600), (610, 355, 740)] {
            let threshold = viewport - center - height * 0.25
            precondition(!CardPreviewDrag.shouldDismiss(translation: threshold - 0.01,
                cardHeight: height, centerY: center, viewportHeight: viewport), "Below 25% stays open")
            precondition(CardPreviewDrag.shouldDismiss(translation: threshold,
                cardHeight: height, centerY: center, viewportHeight: viewport), "Exactly 25% closes")
            precondition(CardPreviewDrag.shouldDismiss(translation: threshold + 1,
                cardHeight: height, centerY: center, viewportHeight: viewport))
        }
        precondition(!CardPreviewDrag.shouldDismiss(translation: 132.5, cardHeight: 530,
            centerY: 310, viewportHeight: 650), "25% finger travel is not 25% hidden")
        precondition(!CardPreviewDrag.shouldDismiss(translation: .nan, cardHeight: 530,
            centerY: 310, viewportHeight: 650))
        precondition(!CardPreviewDrag.shouldDismiss(translation: 200, cardHeight: 0,
            centerY: 310, viewportHeight: 650))

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

        // Two fingers behave like a photo: their centroid is handled by CardZoom,
        // while only the actual twist changes the card orientation. UIKit reports
        // a clockwise-positive angle, which is negated for scene coordinates.
        card.reset()
        card.begin(x: 0, y: 0, width: 320, height: 200, at: 0)
        card.update(x: 96, y: 0)
        card.end(at: 0, scheduleReturn: false)
        card.beginPhotoTransform(at: 0)
        card.updatePhotoTransform(roll: .pi / 2)
        let photoRotated = card.orientation
        precondition(abs(photoRotated.imag.y) > 0.01 && abs(photoRotated.imag.z) > 0.01,
                     "Photo transform must retain the incoming yaw and follow the finger twist")
        card.end(at: 1, scheduleReturn: false)
        card.returnToDefault(at: 1, duration: CardZoom.returnDuration)
        card.advance(at: 1.15)
        precondition(simd_length(card.orientation.vector - photoRotated.vector) > 0.01,
                     "Photo orientation must animate back together with zoom")
        card.advance(at: 1.301)
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

        print("PASS: one-finger Y-only yaw, photo-like two-finger roll with immediate coordinated reset, horizontal layout, anchored simultaneous zoom and pan, 3s deadline, 600ms drag return, cancellation, regrab, full turns, event rate, zoom limits and reset")
    }
}

import XCTest

final class CardFlowUITests: XCTestCase {
    @MainActor
    func testWarmPlasticColorsDoNotLoadOrRebuildResources() {
        let app = launchCardSelection(diagnostics: true)
        let ring = app.descendants(matching: .any).matching(identifier: "colorSelectionFrame").firstMatch
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "prepareComplete=5"), object: ring)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed)
        Thread.sleep(forTimeInterval: 1)
        let before = plasticCounters(ring)
        for index in [1, 2, 3, 4, 0, 4, 2, 1, 3, 0] {
            app.buttons["cardColor\(index)"].tap()
            XCTAssertTrue(waitForValue(of: ring, containing: "\(index + 1) of 5"))
        }
        let after = plasticCounters(ring)
        for metric in ["coldPrepare", "textureLoad", "inkRasterization", "meshBuild", "loaderShown"] {
            XCTAssertEqual(after[metric], before[metric], "Warm selection must not repeat \(metric)")
        }
        XCTAssertGreaterThan(after["atomicApply", default: 0], before["atomicApply", default: 0])
        attach("plastic-ready-resource-reuse", app)
    }

    @MainActor
    private func plasticCounters(_ ring: XCUIElement) -> [String: Int] {
        let value = (ring.value as? String ?? "").components(separatedBy: "; ").last ?? ""
        return Dictionary(uniqueKeysWithValues: value.split(separator: ",").compactMap {
            let parts = $0.split(separator: "=")
            guard parts.count == 2, let count = Int(parts[1]) else { return nil }
            return (String(parts[0]), count)
        })
    }

    @MainActor
    func testPlasticColorPerformance() {
        let app = launchCardSelection()
        let ring = app.descendants(matching: .any).matching(identifier: "colorSelectionFrame").firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 3)
        let options = XCTMeasureOptions()
        options.iterationCount = 2
        var metrics: [XCTMetric] = [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)]
        if #available(iOS 26.0, *) { metrics.append(XCTHitchMetric(application: app)) }
        measure(metrics: metrics, options: options) {
            let center = ring.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            for direction in [-1.0, -1, -1, -1, 1, 1, 1, 1] {
                center.press(forDuration: 0.05,
                             thenDragTo: center.withOffset(CGVector(dx: 56 * direction, dy: 0)),
                             withVelocity: XCUIGestureVelocity(400), thenHoldForDuration: 0)
            }
        }
        XCTAssertTrue(waitForValue(of: ring, containing: "1 of 5"))
        attach("plastic-performance-settled", app)
    }

    @MainActor
    func testPreviewEntrancePerformance() {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        Thread.sleep(forTimeInterval: 3)
        let options = XCTMeasureOptions()
        options.iterationCount = 2
        var metrics: [XCTMetric] = [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)]
        if #available(iOS 26.0, *) { metrics.append(XCTHitchMetric(application: app)) }
        measure(metrics: metrics, options: options) {
            card.tap()
            XCTAssertTrue(app.buttons["Back to designs"].waitForExistence(timeout: 3))
            Thread.sleep(forTimeInterval: 1.1)
            app.buttons["Back to designs"].tap()
            XCTAssertTrue(app.buttons["Back to designs"].waitForNonExistence(timeout: 3))
        }
    }

    /// Run separately from functional suites, preferably in Release on the
    /// review phone. Simulator CPU/GPU timings are not device frame budgets.
    @MainActor
    func testPhysicalGallerySwipePerformance() {
        measureGallerySwipes(digital: false)
    }

    @MainActor
    func testDigitalGallerySwipePerformance() {
        measureGallerySwipes(digital: true)
    }

    @MainActor
    private func measureGallerySwipes(digital: Bool) {
        let app = launchCardSelection(digital: digital)
        let card = activeCard(in: app)
        let ring = app.descendants(matching: .any).matching(identifier: "colorSelectionFrame").firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 3)
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        var metrics: [XCTMetric] = [XCTClockMetric(), XCTCPUMetric(application: app),
                                    XCTMemoryMetric(application: app)]
        if #available(iOS 26.0, *) { metrics.append(XCTHitchMetric(application: app)) }
        measure(metrics: metrics, options: options) {
            if digital {
                let center = ring.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                // Includes reversal and repeated colors, not just a single warm tap.
                for direction in [-1.0, 1.0, -1.0, 1.0] {
                    center.press(forDuration: 0.05,
                                 thenDragTo: center.withOffset(CGVector(dx: 56 * direction, dy: 0)),
                                 withVelocity: XCUIGestureVelocity(300), thenHoldForDuration: 0)
                }
            } else {
                card.swipeLeft(velocity: .slow)
                card.swipeRight(velocity: .slow)
                card.swipeLeft(velocity: .slow)
                card.swipeRight(velocity: .slow)
            }
        }
        XCTAssertTrue(app.buttons["bottomAction"].exists)
        XCTAssertTrue(waitForValue(of: ring, containing: digital ? "1 of 4" : "1 of 5"))
    }

    @MainActor
    func testInactiveChooseKeepsReviewedOrangeAppearance() throws {
        let app = launchCardSelection()
        let action = app.buttons["bottomAction"]
        XCTAssertFalse(action.isEnabled)
        let image = try XCTUnwrap(action.screenshot().image.cgImage)
        let sample = try XCTUnwrap(image.cropping(to: CGRect(x: image.width / 2, y: 10, width: 1, height: 1)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
            bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertEqual(Int(pixel[0]), 255, accuracy: 2)
        XCTAssertEqual(Int(pixel[1]), 80, accuracy: 2)
        XCTAssertEqual(Int(pixel[2]), 0, accuracy: 2)
        assertChooseIsInert(app)
        attach("preview-only-unchanged-orange", app)
    }

    @MainActor
    func testChooseDesignIsInertAndCardPreviewStillWorks() {
        for digital in [false, true] {
            let app = launchCardSelection(digital: digital)
            let card = activeCard(in: app)
            assertChooseIsInert(app)
            if !digital {
                card.swipeLeft()
                XCTAssertTrue(waitForLabel(of: card, containing: "Metal"))
                assertChooseIsInert(app)
            }
            attach(digital ? "digital-disabled-choose" : "physical-disabled-choose", app)
            card.tap()
            XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
            assertChooseIsInert(app)
            XCTAssertTrue(app.staticTexts["Card preview"].exists)
            app.buttons["Back to designs"].tap()
            XCTAssertTrue(app.staticTexts["Card preview"].waitForNonExistence(timeout: 3))
            XCTAssertTrue(card.exists)
        }
    }

    @MainActor
    private func assertChooseIsInert(_ app: XCUIApplication) {
        let action = app.buttons["bottomAction"]
        XCTAssertTrue(action.exists)
        XCTAssertFalse(action.isEnabled)
        action.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(activeCard(in: app).exists)
        XCTAssertFalse(app.otherElements["setupInteractiveCard"].exists)
        XCTAssertFalse(app.buttons["setupContinueButton"].exists)
    }

    @MainActor
    func testPreviewZoomUnderNativeScrollEdges() {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        let buttonFrame = app.buttons["bottomAction"].frame
        card.swipeLeft()
        XCTAssertTrue(waitForLabel(of: card, containing: "Metal, type"))
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        let initial = card.screenshot().pngRepresentation
        attach("edge-fix-metal-default", app)
        // Slow real pinches allow a recording to inspect the actual held/zoomed
        // render under both bars, not a synthetic substitute for the gesture.
        card.pinch(withScale: 3, velocity: 0.35)
        let peak = Double((card.value as? String ?? "").components(separatedBy: "zoom:").last ?? "") ?? 1
        XCTAssertGreaterThan(peak, 2.5, "Exercise a real large pinch, like the reported screen")
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(card.screenshot().pngRepresentation, initial)
        XCTAssertEqual(app.buttons["bottomAction"].frame, buttonFrame)
        XCTAssertTrue(app.buttons["Back to designs"].isHittable)
        attach("edge-fix-metal-restored", app)
        app.buttons["Back to designs"].tap()
        XCTAssertTrue(waitForLabel(of: card, containing: "Metal, type"))
    }

    @MainActor
    func testNoCardShineAndPreviewEntranceSettles() {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        Thread.sleep(forTimeInterval: 2)
        let resting = card.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 1.3)
        XCTAssertEqual(card.screenshot().pngRepresentation, resting, "No entrance shine on the card")
        Thread.sleep(forTimeInterval: 1.3)
        XCTAssertEqual(card.screenshot().pngRepresentation, resting, "No delayed card shine")
        attach("soft-edge-plastic-gallery", app)
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.2)
        let front = card.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertEqual(card.screenshot().pngRepresentation, front, "Entry must settle after one subtle rock")
        attach("soft-edge-plastic-preview", app)
        app.buttons["Back to designs"].tap()
        XCTAssertTrue(waitForLabel(of: card, containing: "Plastic, type"))
        card.swipeLeft()
        XCTAssertTrue(waitForLabel(of: card, containing: "Metal, type"))
        Thread.sleep(forTimeInterval: 2.2)
        attach("soft-edge-metal-gallery", app)
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.9)
        attach("soft-edge-metal-preview", app)
    }

    @MainActor
    func testPhysicalTypesAndIndependentColorRail() {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        let ring = app.descendants(matching: .any).matching(identifier: "colorSelectionFrame").firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("Plastic, type 1 of 2"))
        XCTAssertEqual(app.buttons["bottomAction"].label, "Choose this design")
        Thread.sleep(forTimeInterval: 2.6)
        attach("gallery-plastic-figma", app)
        let ringFrame = ring.frame
        XCTAssertEqual(ringFrame.width, 48, accuracy: 0.5)
        XCTAssertEqual(ringFrame.midX, app.frame.midX, accuracy: 0.5)
        XCTAssertEqual(ringFrame.minY, app.frame.height - 218, accuracy: 0.5,
                       "Color ring must match the Figma bottom anchor")

        let start = ring.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.08, thenDragTo: start.withOffset(CGVector(dx: -56, dy: 0)),
                    withVelocity: .slow, thenHoldForDuration: 0.15)
        XCTAssertTrue(waitForValue(of: ring, containing: "2 of 5"))
        XCTAssertEqual(ring.frame, ringFrame, "The selection ring must not travel with the colors")
        XCTAssertTrue(card.label.contains("Plastic"), "Color swipe must never switch product type")
        attach("gallery-plastic-color-swiped", app)
        for index in 2...4 {
            app.buttons["cardColor\(index)"].tap()
            XCTAssertTrue(waitForValue(of: ring, containing: "\(index + 1) of 5"))
            XCTAssertEqual(ring.frame, ringFrame)
        }
        XCTAssertTrue((ring.value as? String ?? "").contains("Cobalto"))
        card.swipeLeft()
        XCTAssertTrue(waitForLabel(of: card, containing: "Metal, type 2 of 2"))
        XCTAssertTrue(waitForValue(of: ring, containing: "Plata, 1 of 2"))
        XCTAssertEqual(app.buttons["bottomAction"].label, "Choose this design")
        Thread.sleep(forTimeInterval: 0.8)
        attach("gallery-metal-figma", app)
        app.buttons["cardColor1"].tap()
        XCTAssertTrue(waitForValue(of: ring, containing: "Obsidiana, 2 of 2"))
        Thread.sleep(forTimeInterval: 0.8)
        attach("gallery-metal-obsidiana", app)
        XCTAssertEqual(ring.frame, ringFrame)
        card.swipeRight()
        XCTAssertTrue(waitForLabel(of: card, containing: "Plastic, type 1 of 2"))
        XCTAssertTrue(waitForValue(of: ring, containing: "Cobalto, 5 of 5"),
                      "Each product type remembers its finish")
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        app.buttons["Back to designs"].tap()
        XCTAssertTrue(waitForValue(of: ring, containing: "Cobalto, 5 of 5"))
    }

    @MainActor
    func testColorFlickAndMidpointCommit() {
        let app = launchCardSelection(digital: true)
        let card = activeCard(in: app)
        let ring = app.descendants(matching: .any).matching(identifier: "colorSelectionFrame").firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        let frame = ring.frame
        let center = ring.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.08, thenDragTo: center.withOffset(CGVector(dx: -23, dy: 0)),
                     withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(waitForValue(of: ring, containing: "1 of 4"))
        XCTAssertTrue((card.value as? String ?? "").contains("haptics:0"))
        center.press(forDuration: 0.08, thenDragTo: center.withOffset(CGVector(dx: -30, dy: 0)),
                     withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(waitForValue(of: ring, containing: "2 of 4"))
        XCTAssertTrue((card.value as? String ?? "").contains("haptics:1"))
        center.press(forDuration: 0.08, thenDragTo: center.withOffset(CGVector(dx: 30, dy: 0)),
                     withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(waitForValue(of: ring, containing: "1 of 4"))
        XCTAssertTrue((card.value as? String ?? "").contains("haptics:2"))
        let right = center.withOffset(CGVector(dx: 170, dy: 0))
        let left = center.withOffset(CGVector(dx: -170, dy: 0))
        right.press(forDuration: 0.05, thenDragTo: left,
                    withVelocity: XCUIGestureVelocity(2000), thenHoldForDuration: 0)
        XCTAssertTrue(waitForValue(of: ring, containing: "2 of 4"), "A fast full-width flick advances only one color")
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue((ring.value as? String ?? "").contains("2 of 4"), "No release inertia may change selection")
        right.press(forDuration: 0.1, thenDragTo: left,
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(waitForValue(of: ring, containing: "4 of 4"), "Held movement can traverse successive colors")
        XCTAssertEqual(ring.frame, frame)
        attach("gallery-continuous-color-drag", app)
    }

    @MainActor
    func testTypeMidpointConfirmsReleaseAndSubtitle() {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        let ring = app.descendants(matching: .any).matching(identifier: "colorSelectionFrame").firstMatch
        let ringFrame = ring.frame
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        let plasticWidth = app.frame.width - 56
        let midpoint = (plasticWidth + 16) * 0.62 / 2
        start.press(forDuration: 0.08, thenDragTo: start.withOffset(CGVector(dx: -(midpoint - 3), dy: 0)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(waitForLabel(of: card, containing: "Plastic"))
        XCTAssertTrue((card.value as? String ?? "").contains("haptics:0"))
        start.press(forDuration: 0.08, thenDragTo: start.withOffset(CGVector(dx: -(midpoint + 3), dy: 0)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(waitForLabel(of: card, containing: "Metal"))
        XCTAssertEqual(ring.frame, ringFrame, "Palette crossfade must not move the selection ring")
        XCTAssertEqual(app.buttons["cardColor0"].frame.width, 40, accuracy: 0.5)
        XCTAssertTrue((card.value as? String ?? "").contains("haptics:1"))
        let subtitle = app.descendants(matching: .any).matching(identifier: "galleryDescription").firstMatch
        XCTAssertTrue(subtitle.label.contains("Plata—polished silver"))
        let reverse = card.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        reverse.press(forDuration: 0.08, thenDragTo: reverse.withOffset(CGVector(dx: midpoint + 3, dy: 0)),
                      withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(waitForLabel(of: card, containing: "Plastic"))
        XCTAssertEqual(ring.frame, ringFrame)
        XCTAssertEqual(app.buttons["cardColor0"].frame.width, 40, accuracy: 0.5)
        XCTAssertTrue((card.value as? String ?? "").contains("haptics:2"))
        XCTAssertEqual(subtitle.label, "Plata—matte grey, quiet and clean")
        attach("gallery-plastic-final", app)
    }

    @MainActor
    func testCobaltoHasNoWhiteInspectionHotspot() throws {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        let ring = app.descendants(matching: .any).matching(identifier: "colorSelectionFrame").firstMatch
        app.buttons["cardColor2"].tap()
        app.buttons["cardColor4"].tap()
        XCTAssertTrue(waitForValue(of: ring, containing: "Cobalto, 5 of 5"))
        Thread.sleep(forTimeInterval: 1)
        let image = try XCTUnwrap(card.screenshot().image.cgImage)
        // The open blue area inside L, excluding the printed letter itself.
        let rect = CGRect(x: Double(image.width) * 0.29, y: Double(image.height) * 0.055,
                          width: Double(image.width) * 0.04, height: Double(image.height) * 0.05)
        let patch = try XCTUnwrap(image.cropping(to: rect))
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8,
                    bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.interpolationQuality = .high
        context.draw(patch, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        XCTAssertLessThan(Int(pixel[0]), 120, "Cobalto must stay blue here, not clip to a white glow")
        XCTAssertGreaterThan(Int(pixel[2]) - Int(pixel[0]), 40, "Original blue substrate remains visible")
        attach("cobalto-no-hotspot", app)
    }

    @MainActor
    func testShortTypeFlickCompletesInBothDirections() {
        let app = launchCardSelection()
        XCTAssertTrue(app.staticTexts["Tap for a closer look"].exists)
        let card = activeCard(in: app)
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -75, dy: 0)),
                    withVelocity: XCUIGestureVelocity(1200), thenHoldForDuration: 0)
        XCTAssertTrue(waitForLabel(of: card, containing: "Metal"), "Short fast flick must complete to Metal")
        let reverse = card.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
        reverse.press(forDuration: 0.05, thenDragTo: reverse.withOffset(CGVector(dx: 75, dy: 0)),
                      withVelocity: XCUIGestureVelocity(1200), thenHoldForDuration: 0)
        XCTAssertTrue(waitForLabel(of: card, containing: "Plastic"), "Short reverse flick must complete to Plastic")
        XCTAssertTrue((card.value as? String ?? "").contains("haptics:2"))
        attach("type-short-flick-final", app)
    }

    @MainActor
    func testPlasticFinishesDescriptionsAndPreview() {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        let ring = app.descendants(matching: .any).matching(identifier: "colorSelectionFrame").firstMatch
        let description = app.descendants(matching: .any).matching(identifier: "galleryDescription").firstMatch
        let copy = ["Plata—matte grey, quiet and clean", "Rosé—brushed finish, catches the light",
                    "Barro—burnt terracotta, warm and matte", "Hueso—bone white, soft matte",
                    "Cobalto—deep talavera blue"]
        let heading = app.descendants(matching: .any).matching(identifier: "morphTitle").firstMatch
        let action = app.buttons["bottomAction"]
        let actionFrame = action.frame
        let actionPixels = action.screenshot().pngRepresentation
        XCTAssertEqual(card.frame.minX, 28, accuracy: 0.5)
        XCTAssertEqual(card.frame.maxX, app.frame.width - 28, accuracy: 0.5)
        XCTAssertEqual(card.frame.width / card.frame.height, 85.60 / 53.98, accuracy: 0.01)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "galleryPreviewHint").firstMatch.exists)
        let ringFrame = ring.frame
        var faces = Set<Data>()
        for index in copy.indices {
            if index > 0 { app.buttons["cardColor\(index)"].tap() }
            XCTAssertTrue(waitForValue(of: ring, containing: "\(index + 1) of 5"))
            XCTAssertEqual(description.label, copy[index])
            XCTAssertEqual(heading.label, index == 0 ? "Plastic • Free" : "Plastic • $40")
            XCTAssertEqual(action.label, "Choose this design")
            XCTAssertEqual(action.frame, actionFrame)
            XCTAssertEqual(action.screenshot().pngRepresentation, actionPixels)
            Thread.sleep(forTimeInterval: 1)
            XCTAssertEqual(ring.frame, ringFrame)
            assertPhysicalWidth(in: app, card: card)
            faces.insert(card.screenshot().pngRepresentation)
            attach("plastic-finish-\(index)", app)
        }
        XCTAssertEqual(faces.count, 5, "Every finish must change the actual card, not only its label")
        assertChooseIsInert(app)
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        app.buttons["Back to designs"].tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(waitForValue(of: ring, containing: "Cobalto, 5 of 5"))
        assertPhysicalWidth(in: app, card: card)
        attach("plastic-cobalto-restored", app)
    }

    @MainActor
    func testMetalMaterialsAndSharedOrangeButton() {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        let plasticButton = app.buttons["bottomAction"].frame
        let plasticPixels = app.buttons["bottomAction"].screenshot().pngRepresentation
        card.swipeLeft()
        XCTAssertTrue(waitForLabel(of: card, containing: "Metal"))
        XCTAssertEqual(app.buttons["bottomAction"].frame, plasticButton, "Both CTA height and baseline match")
        XCTAssertEqual(app.buttons["bottomAction"].label, "Choose this design")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "morphTitle").firstMatch.label, "Metal • $40")
        Thread.sleep(forTimeInterval: 3)
        let button = app.buttons["bottomAction"]
        let settledButton = button.screenshot().pngRepresentation
        XCTAssertEqual(settledButton, plasticPixels, "Metal uses exactly the same orange CTA as Plastic")
        Thread.sleep(forTimeInterval: 0.75)
        XCTAssertEqual(button.screenshot().pngRepresentation, settledButton, "No legacy Plus glow")
        let plata = card.screenshot().pngRepresentation
        attach("gallery-metal-plata-final", app)
        app.buttons["cardColor1"].tap()
        let ring = app.descendants(matching: .any).matching(identifier: "colorSelectionFrame").firstMatch
        XCTAssertTrue(waitForValue(of: ring, containing: "Obsidiana, 2 of 2"))
        Thread.sleep(forTimeInterval: 1)
        XCTAssertNotEqual(card.screenshot().pngRepresentation, plata, "The actual Metal material must change")
        XCTAssertEqual(button.frame, plasticButton)
        attach("gallery-metal-obsidiana-final", app)
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        card.pinch(withScale: 2, velocity: 0.7)
        let peak = Double((card.value as? String ?? "").components(separatedBy: "zoom:").last ?? "") ?? 1
        XCTAssertGreaterThan(peak, 1.5, "RealityKit keeps the existing anchored pinch contract")
        attach("gallery-metal-obsidiana-preview", app)
    }

    @MainActor
    func testDigitalHasColorsButNoTypeCarousel() {
        let app = launchCardSelection(digital: true)
        let card = activeCard(in: app)
        let ring = app.descendants(matching: .any).matching(identifier: "colorSelectionFrame").firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        XCTAssertEqual(card.label, "Digital card")
        XCTAssertEqual(app.buttons["bottomAction"].label, "Choose this design")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "morphTitle").firstMatch.label, "Digital")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "card1").firstMatch.exists)
        Thread.sleep(forTimeInterval: 2.6)
        attach("gallery-digital-amanecer", app)
        assertDigitalWidth(in: app, card: card)
        let subtitle = app.descendants(matching: .any).matching(identifier: "galleryDescription").firstMatch
        XCTAssertEqual(subtitle.label, "Amanecer—warm light, a new beginning")
        var previousFace = card.screenshot().pngRepresentation
        let ringFrame = ring.frame
        let cardFrame = card.frame
        card.swipeLeft()
        card.swipeRight()
        XCTAssertEqual(card.label, "Digital card")
        XCTAssertEqual(card.frame, cardFrame, "Digital artwork must not slide between product types")
        XCTAssertTrue(waitForValue(of: ring, containing: "Amanecer, 1 of 4"))
        let descriptions = ["Amanecer—warm light, a new beginning",
                            "Jacarandá—violet light in full bloom",
                            "Cenote—clear light, quiet depth",
                            "Noche—a sliver of light after dark"]
        for index in 1...3 {
            app.buttons["cardColor\(index)"].tap()
            XCTAssertTrue(waitForValue(of: ring, containing: "\(index + 1) of 4"))
            XCTAssertEqual(ring.frame, ringFrame)
            XCTAssertTrue(waitForLabel(of: subtitle, containing: descriptions[index]))
            Thread.sleep(forTimeInterval: 1.2)
            let face = card.screenshot().pngRepresentation
            XCTAssertNotEqual(face, previousFace, "The real Digital material must change")
            previousFace = face
            assertDigitalWidth(in: app, card: card)
            attach("gallery-digital-skin-\(index)", app)
        }
        attach("gallery-digital-last-color", app)
        let end = ring.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        end.press(forDuration: 0.08, thenDragTo: end.withOffset(CGVector(dx: 56, dy: 0)),
                  withVelocity: .slow, thenHoldForDuration: 0.15)
        XCTAssertTrue(waitForValue(of: ring, containing: "Cenote, 3 of 4"))
        XCTAssertEqual(ring.frame, ringFrame)
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        attach("gallery-digital-cenote-preview", app)
        let previewFace = card.screenshot().pngRepresentation
        card.pinch(withScale: 2.5, velocity: 0.6)
        let peak = Double((card.value as? String ?? "").components(separatedBy: "zoom:").last ?? "") ?? 1
        XCTAssertGreaterThan(peak, 2)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(card.screenshot().pngRepresentation, previewFace)
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        start.press(forDuration: 0.08, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 260)),
                    withVelocity: .slow, thenHoldForDuration: 0.15)
        XCTAssertTrue(waitForLabel(of: card, containing: "Digital card"))
        XCTAssertTrue(waitForValue(of: ring, containing: "Cenote, 3 of 4"))
        assertChooseIsInert(app)
        assertDigitalWidth(in: app, card: card)

    }

    @MainActor
    func testHorizontalRotationAndInertialReturn() throws {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1.2)
        let initial = card.screenshot().pngRepresentation

        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .press(forDuration: 0.1,
                   thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.05)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(card.screenshot().pngRepresentation, initial,
                       "A short downward drag bounces back without rotating the card")

        card.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
            .press(forDuration: 0.1,
                   thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.05)
        // XCTest can wait for animation idleness before returning from the
        // synthesized gesture. Direction/speed/travel are checked with the
        // deterministic physics clock; the recording verifies visible motion.
        let gentlyRotated = card.screenshot().pngRepresentation
        XCTAssertNotEqual(gentlyRotated, initial, "A gentle drag changes the pose")
        Thread.sleep(forTimeInterval: 4)
        XCTAssertEqual(card.screenshot().pngRepresentation, gentlyRotated,
                       "Gentle release stays still, including beyond the old return delay")
        attach("inertia-gentle-held", app)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 0.05,
                   thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)),
                   withVelocity: XCUIGestureVelocity(1400), thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 11)
        XCTAssertEqual(card.screenshot().pngRepresentation, initial,
                       "A stronger opposite flick also settles front-facing")
        attach("inertia-strong-front", app)
    }

    @MainActor
    func testTwoFingerPhotoTransformReturnsToDefault() throws {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.8)
        let initial = card.screenshot().pngRepresentation

        card.pinch(withScale: 2, velocity: 0.7)
        Thread.sleep(forTimeInterval: 0.15)
        let peak = Double((card.value as? String ?? "").components(separatedBy: "zoom:").last ?? "") ?? 1
        XCTAssertGreaterThan(peak, 1.5, "The real two-finger gesture must actually magnify the card")
        // XCTest may idle until the 300 ms return is over. Verify the observed
        // gesture peak, not a race to screenshot its transient magnified state.
        attach("interaction-03-pinch", app)

        Thread.sleep(forTimeInterval: 0.65)
        XCTAssertEqual(card.screenshot().pngRepresentation, initial,
                       "Scale, translation and twist must return together immediately after pinch")
    }

    @MainActor
    func testPreviewTypeSheetAndFullscreenGalleryReturn() throws {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["cardPreviewButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertEqual(start.label, "Card preview")
        XCTAssertFalse(app.buttons["startFlowButton"].exists)
        XCTAssertFalse(app.buttons["settingsButton"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        attach("preview-launcher", app)
        start.tap()
        XCTAssertTrue(app.buttons["issuePhysicalCardButton"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["orderForMeButton"].exists)
        XCTAssertFalse(app.staticTexts["Another person"].exists)
        XCTAssertEqual(app.navigationBars["Select card type"].buttons.count, 0)
        attach("preview-type-sheet", app)
        app.buttons["issuePhysicalCardButton"].tap()
        XCTAssertTrue(app.buttons["bottomAction"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.tabBars.firstMatch.waitForNonExistence(timeout: 3),
                      "The preview flow has no account tabs")
        Thread.sleep(forTimeInterval: 0.55)
        attach("push-gallery-no-shine", app)
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 3), "Gallery must use the native navigation back button")
        back.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["metalPreviewButton"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        start.tap()
        XCTAssertTrue(app.buttons["issueDigitalCardButton"].waitForExistence(timeout: 3))
        app.buttons["issueDigitalCardButton"].tap()
        XCTAssertTrue(app.buttons["bottomAction"].waitForExistence(timeout: 5),
                      "Digital enters a separate no-carousel gallery")
        XCTAssertFalse(app.buttons["orderForMeButton"].exists)
        XCTAssertEqual(activeCard(in: app).label, "Digital card")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 3))
    }

    @MainActor
    func testPreviewDragBouncesThenDismissesKeepingSelection() {
        let app = launchCardSelection()
        let card = activeCard(in: app)
        card.swipeLeft()
        XCTAssertTrue(waitForLabel(of: card, containing: "Metal"))
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.8)
        let initial = card.frame
        let start = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 160)),
                    withVelocity: .slow, thenHoldForDuration: 0.6)
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(app.staticTexts["Card preview"].exists)
        XCTAssertGreaterThan(Double((card.value as? String ?? "").components(separatedBy: "|").first ?? "") ?? 0, 100,
                             "Short drag must actually move the card before bouncing back")
        XCTAssertEqual(card.frame.midY, initial.midY, accuracy: 1)
        attach("preview-01-bounced-back", app)

        card.pinch(withScale: 1.6, velocity: 0.7)
        Thread.sleep(forTimeInterval: 0.7)
        let dismissStart = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        // The card clips above the bottom CTA. Stop at 30% hidden: this closes
        // at the new 25% threshold but would fail the old 50% implementation.
        let viewportBottom = app.buttons["bottomAction"].frame.minY - 8
        let viewportHeight = viewportBottom - app.navigationBars.firstMatch.frame.maxY
        // XCUI reports the clipped accessibility container, not the rotated
        // card's rendered bounds. Derive the actual portrait height from layout.
        let portraitHeight = min(viewportHeight - 78, (app.frame.width - 92) * 1.72)
        let dismissDistance = viewportHeight * 0.52 - portraitHeight * 0.20
        dismissStart.press(forDuration: 0.1,
                           thenDragTo: dismissStart.withOffset(CGVector(dx: 0, dy: dismissDistance)),
                           withVelocity: .slow, thenHoldForDuration: 0.05)
        XCTAssertTrue(app.buttons["bottomAction"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Card preview"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(waitForLabel(of: card, containing: "type 2 of"))
        XCTAssertTrue(card.label.contains("Metal"))
        attach("preview-02-drag-dismissed", app)
        assertChooseIsInert(app)
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3),
                      "The same card can be opened again after drag dismissal")
    }

    @MainActor
    private func launchCardSelection(digital: Bool = false, diagnostics: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--card-gesture-probe"]
        if diagnostics { app.launchArguments.append("--plata-plastic-diagnostics") }
        app.launch()
        let start = app.buttons["cardPreviewButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "The preview launcher is the launch screen")
        start.tap()
        XCTAssertTrue(app.buttons["issuePhysicalCardButton"].waitForExistence(timeout: 3))
        app.buttons[digital ? "issueDigitalCardButton" : "issuePhysicalCardButton"].tap()
        XCTAssertTrue(app.buttons["bottomAction"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func activeCard(in app: XCUIApplication) -> XCUIElement {
        let card = app.descendants(matching: .any).matching(identifier: "activeCard").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        return card
    }

    @MainActor
    private func waitForLabel(of element: XCUIElement, containing text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }

    @MainActor
    private func waitForValue(of element: XCUIElement, containing text: String) -> Bool {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", text), object: element)
        return XCTWaiter.wait(for: [ready], timeout: 4) == .completed
    }

    @MainActor
    private func assertDigitalWidth(in app: XCUIApplication, card: XCUIElement,
                                    file: StaticString = #filePath, line: UInt = #line) {
        // Measure real rendered pixels, not just the SwiftUI accessibility slot.
        // A late renderer camera fit used to enlarge the card outside this slot.
        guard let image = app.screenshot().image.cgImage else {
            XCTFail("Missing screenshot", file: file, line: line); return
        }
        let scale = CGFloat(image.width) / app.frame.width
        let y = min(image.height - 1, max(0, Int(card.frame.midY * scale)))
        guard let row = image.cropping(to: CGRect(x: 0, y: y, width: image.width, height: 1)) else {
            XCTFail("Missing card scanline", file: file, line: line); return
        }
        var pixels = [UInt8](repeating: 0, count: image.width * 4)
        let context = CGContext(data: &pixels, width: image.width, height: 1, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(row, in: CGRect(x: 0, y: 0, width: image.width, height: 1))
        let body = (0..<image.width).filter { x in
            let rgb = [pixels[x * 4], pixels[x * 4 + 1], pixels[x * 4 + 2]]
            return Int(rgb.max()!) - Int(rgb.min()!) > 24
        }
        let actual = body.first.flatMap { first in body.last.map { CGFloat($0 - first + 1) / scale } } ?? 0
        let expected = min(card.frame.width, card.frame.height * 85.60 / 53.98)
        XCTAssertEqual(actual, expected, accuracy: 2, "Digital must be visible and fitted without stretching", file: file, line: line)
    }

    @MainActor
    private func assertPhysicalWidth(in app: XCUIApplication, card: XCUIElement,
                                     file: StaticString = #filePath, line: UInt = #line) {
        // Native back rebuilds the released ARView asynchronously. Wait for
        // actual rendered pixels, not just an accessible but still empty slot.
        var actual: CGFloat = 0
        let expected = min(card.frame.width, card.frame.height * 85.60 / 53.98)
        for _ in 0..<12 {
            actual = physicalWidth(in: app, card: card)
            if abs(actual - expected) <= 2 { return }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertEqual(actual, expected, accuracy: 2, "Plastic must render at ID-1 size, including after push/back", file: file, line: line)
    }

    @MainActor
    private func physicalWidth(in app: XCUIApplication, card: XCUIElement) -> CGFloat {
        guard let image = app.screenshot().image.cgImage else { return 0 }
        let scale = CGFloat(image.width) / app.frame.width
        let y = min(image.height - 1, max(0, Int(card.frame.midY * scale)))
        guard let row = image.cropping(to: CGRect(x: 0, y: y, width: image.width, height: 1)) else { return 0 }
        var pixels = [UInt8](repeating: 0, count: image.width * 4)
        let context = CGContext(data: &pixels, width: image.width, height: 1, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(row, in: CGRect(x: 0, y: 0, width: image.width, height: 1))
        let expected = min(card.frame.width, card.frame.height * 85.60 / 53.98)
        let low = max(0, Int((card.frame.midX - expected / 2 - 8) * scale))
        let high = min(image.width - 1, Int((card.frame.midX + expected / 2 + 8) * scale))
        let background = (0..<3).map { Int(pixels[low * 4 + $0]) }
        let body = (low...high).filter { x in
            (0..<3).reduce(0) { $0 + abs(Int(pixels[x * 4 + $1]) - background[$1]) } > 45
        }
        return body.first.flatMap { first in body.last.map { CGFloat($0 - first + 1) / scale } } ?? 0
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

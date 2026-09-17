import XCTest

final class CardFlowUITests: XCTestCase {
    @MainActor
    func testHorizontalRotationAndTimedReturn() throws {
        let app = launchCardSelection()
        let card = app.descendants(matching: .any).matching(identifier: "activeCard").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.8)
        let initial = card.screenshot().pngRepresentation
        card.tap()
        XCTAssertEqual(card.screenshot().pngRepresentation, initial, "A tap must not flip or tilt the card")
        attach("rotation-01-front", app)

        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)),
                   withVelocity: .slow, thenHoldForDuration: 0.05)
        XCTAssertEqual(card.screenshot().pngRepresentation, initial,
                       "Vertical movement must leave orientation unchanged")

        card.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5)),
                   withVelocity: .slow, thenHoldForDuration: 0.05)
        let partial = card.screenshot().pngRepresentation
        XCTAssertNotEqual(partial, initial, "Horizontal movement must visibly rotate the card")
        Thread.sleep(forTimeInterval: 0.7)
        XCTAssertEqual(card.screenshot().pngRepresentation, partial,
                       "The exact released angle is retained during the initial three-second hold")
        attach("rotation-02-before-deadline", app)
        // The injected-clock numerical checks verify the exact 3.0s boundary
        // and 600ms duration; UI calls also include IPC/screenshot latency.
        Thread.sleep(forTimeInterval: 3.8)
        XCTAssertEqual(card.screenshot().pngRepresentation, initial,
                       "After the hold and 600ms return, the card is front-facing again")
        attach("rotation-03-returned-front", app)
        app.buttons["bottomAction"].tap()
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        attach("rotation-04-front-on-reopen", app)
    }

    @MainActor
    func testTwoFingerFreeTransformAndReturn() throws {
        let app = launchCardSelection()
        let card = app.descendants(matching: .any).matching(identifier: "activeCard").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 0.8)
        let initial = card.screenshot().pngRepresentation
        card.pinch(withScale: 2, velocity: 0.7)
        // XCUI synthesizes a moving two-finger pinch, so the resulting frame
        // exercises zoom and free rotation together.
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertNotEqual(card.screenshot().pngRepresentation, initial,
                          "Two fingers must be able to zoom and freely rotate the card together")
        attach("two-finger-free-transform", app)
        // Zoom has already returned to 100%; the orientation intentionally holds
        // for three seconds, then takes 600ms to return to the front.
        Thread.sleep(forTimeInterval: 3.8)
        XCTAssertEqual(card.screenshot().pngRepresentation, initial,
                       "The combined transform must return to the default state")
        XCTAssertTrue(app.staticTexts["Card preview"].exists)
        XCTAssertEqual(app.buttons["bottomAction"].label, "Back to designs")
        attach("two-finger-returned-default", app)
    }

    @MainActor
    func testCardFlow() throws {
        let app = launchCardSelection()
        let action = app.buttons["bottomAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 5), "Selection opens after the native ordering flow")
        XCTAssertEqual(action.label, "Order for 799 ₽")
        attach("01-selection", app)
        action.tap()
        XCTAssertEqual(action.label, "Order for 799 ₽", "Order intentionally has no action")
        let card = app.descendants(matching: .any).matching(identifier: "activeCard").firstMatch
        XCTAssertTrue(card.exists)
        let beforeSwipe = card.label
        card.swipeLeft()
        XCTAssertNotEqual(card.label, beforeSwipe)
        let selected = card.label
        card.tap()
        XCTAssertTrue(app.staticTexts["Card preview"].waitForExistence(timeout: 3))
        XCTAssertEqual(action.label, "Back to designs")
        attach("02-preview", app)
        let preview = app.descendants(matching: .any).matching(identifier: "activeCard").firstMatch
        preview.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
            .press(forDuration: 0.3, thenDragTo: preview.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.8)))
        XCTAssertEqual(action.label, "Back to designs")
        action.tap()
        XCTAssertTrue(app.staticTexts["Plastic card"].waitForExistence(timeout: 3))
        XCTAssertEqual(card.label, selected, "Returning retains carousel selection")
        XCTAssertEqual(action.label, "Order for 799 ₽")
        card.tap()
        app.buttons["Back to designs"].firstMatch.tap()
        let selectionState = NSPredicate(format: "label == %@", "Order for 799 ₽")
        expectation(for: selectionState, evaluatedWith: action)
        waitForExpectations(timeout: 3)
    }

    @MainActor
    func testStartFlowOpensGalleryAndCloses() throws {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["startFlowButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertEqual(start.label, "start flow")
        attach("flow-01-start", app)
        start.tap()
        XCTAssertTrue(app.staticTexts["Plastic card"].waitForExistence(timeout: 3))
        attach("flow-02-card-designs", app)
        let close = app.buttons["Close card selection"]
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        close.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 3))
    }

    @MainActor
    private func launchCardSelection() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["startFlowButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "The start screen is the launch screen")
        start.tap()
        XCTAssertTrue(app.buttons["bottomAction"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

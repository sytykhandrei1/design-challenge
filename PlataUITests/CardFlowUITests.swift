import XCTest

final class CardFlowUITests: XCTestCase {
    @MainActor
    func testCardFlow() throws {
        let app = XCUIApplication()
        app.launch()
        let action = app.buttons["bottomAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 5), "Selection opens immediately on launch")
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
        XCTAssertTrue(app.staticTexts["Plastic card"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

import XCTest

final class MorphSettingsUITests: XCTestCase {
    /// Chip order on the settings screen, matching `MorphStyle.allCases`.
    private let techniques = ["Diff", "Stagger", "Shapeshift", "Blur"]

    @MainActor
    func testEveryTechniqueChangesTheNameOnSwipe() throws {
        let app = launchSettings()
        let slider = app.descendants(matching: .any).matching(identifier: "morphSlider").firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 3), "The name slider is on the settings screen")
        let title = app.descendants(matching: .any).matching(identifier: "morphTitle").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "Sand dunes", "The slider starts on the name used under the card")

        for (slot, technique) in techniques.enumerated() {
            let chip = app.buttons["style-\(slot)"]
            XCTAssertTrue(chip.waitForExistence(timeout: 3), "\(technique) is offered on the screen")
            reveal(chip, in: app)
            chip.tap()
            XCTAssertEqual(title.label, "Sand dunes", "\(technique): switching is not a transition")

            slider.swipeLeft()
            waitForLabel(title, toChangeFrom: "Sand dunes", technique: technique)
            XCTAssertEqual(title.label, "Classic Plata")

            slider.swipeRight()
            waitForLabel(title, toChangeFrom: "Classic Plata", technique: technique)
            XCTAssertEqual(title.label, "Sand dunes", "\(technique): swiping back returns the name")
        }
    }

    @MainActor
    private func launchSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let settings = app.buttons["settingsButton"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "The home screen has a settings button")
        settings.tap()
        return app
    }

    /// The technique chips scroll horizontally, so later ones have to be brought into view.
    @MainActor
    private func reveal(_ chip: XCUIElement, in app: XCUIApplication) {
        let row = app.descendants(matching: .any).matching(identifier: "styleRow").firstMatch
        var attempts = 0
        while !chip.isHittable && attempts < 5 {
            row.swipeLeft()
            attempts += 1
        }
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, toChangeFrom old: String, technique: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", old),
                                                    object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 3), .completed,
                       "\(technique): the name should change on swipe")
    }
}

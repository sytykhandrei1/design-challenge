import XCTest

final class MorphSettingsUITests: XCTestCase {
    private let styles = ["Native", "Diff", "Stagger"]

    @MainActor
    func testEveryStyleChangesTheNameOnSwipe() throws {
        let app = launchSettings()
        let slider = app.descendants(matching: .any).matching(identifier: "morphSlider").firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 3), "The name slider is on the settings screen")
        let title = app.descendants(matching: .any).matching(identifier: "morphTitle").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertEqual(title.label, "Sand dunes", "The slider starts on the name used under the card")

        for style in styles {
            app.buttons[style].firstMatch.tap()
            XCTAssertEqual(title.label, "Sand dunes", "Switching technique is not a transition")

            slider.swipeLeft()
            waitForLabel(title, toChangeFrom: "Sand dunes", style: style)
            XCTAssertEqual(title.label, "Classic Plata")

            slider.swipeRight()
            waitForLabel(title, toChangeFrom: "Classic Plata", style: style)
            XCTAssertEqual(title.label, "Sand dunes", "Swiping back returns to the previous name")
        }
    }

    @MainActor
    func testCompareModeDrivesAllThreeTitles() throws {
        let app = launchSettings()
        app.switches["compareAll"].firstMatch.tap()
        let titles = (0..<styles.count).map {
            app.descendants(matching: .any).matching(identifier: "morphTitle-\($0)").firstMatch
        }
        for title in titles {
            XCTAssertTrue(title.waitForExistence(timeout: 3), "Every technique gets its own title")
            XCTAssertEqual(title.label, "Sand dunes")
        }
        app.descendants(matching: .any).matching(identifier: "morphSlider").firstMatch.swipeLeft()
        for (slot, title) in titles.enumerated() {
            waitForLabel(title, toChangeFrom: "Sand dunes", style: styles[slot])
        }
    }

    @MainActor
    private func launchSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let close = app.buttons["Close card selection"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "The app opens into card selection")
        close.tap()
        let settings = app.buttons["settingsButton"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "The account screen has a settings button")
        settings.tap()
        return app
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, toChangeFrom old: String, style: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", old),
                                                    object: element)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 3), .completed,
                       "\(style): the name should change on swipe")
    }
}

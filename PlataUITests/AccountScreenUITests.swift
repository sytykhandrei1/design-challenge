import XCTest

// Retains the registered test file; the account has been replaced by the launcher.
final class AccountScreenUITests: XCTestCase {
    @MainActor
    func testLauncherHasOnlyCardPreviewAndTypeSheetCanBeDismissed() {
        let app = XCUIApplication()
        app.launch()
        let preview = app.buttons["cardPreviewButton"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["metalPreviewButton"].exists)
        XCTAssertFalse(app.scrollViews["accountScrollView"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertFalse(app.buttons["withdrawGalleryButton"].exists)
        XCTAssertEqual(app.navigationBars.buttons.count, 0)
        attach("preview-launcher", app)
        preview.tap()
        let physical = app.buttons["issuePhysicalCardButton"]
        XCTAssertTrue(physical.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["issueDigitalCardButton"].isHittable)
        XCTAssertFalse(app.buttons["orderForMeButton"].exists)
        let header = app.navigationBars["Select card type"]
        XCTAssertTrue(header.exists)
        XCTAssertEqual(header.buttons.count, 0)
        attach("preview-type-sheet", app)
        let dismissalStart = header.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        dismissalStart.press(forDuration: 0.05,
                             thenDragTo: dismissalStart.withOffset(CGVector(dx: 0, dy: 200)),
                             withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(physical.waitForNonExistence(timeout: 4))
        XCTAssertTrue(preview.isHittable)
        preview.tap()
        XCTAssertTrue(physical.waitForExistence(timeout: 3))
    }

    @MainActor
    func testStaggerTitlesSettleAcrossAllCardNames() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["cardPreviewButton"].waitForExistence(timeout: 5))
        app.buttons["cardPreviewButton"].tap()
        XCTAssertTrue(app.buttons["issuePhysicalCardButton"].waitForExistence(timeout: 3))
        app.buttons["issuePhysicalCardButton"].tap()
        let card = app.descendants(matching: .any).matching(identifier: "activeCard").firstMatch
        let title = app.descendants(matching: .any).matching(identifier: "morphTitle").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.swipeLeft()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Metal • $40"), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 4), .completed)
        card.swipeRight()
        card.swipeLeft()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertEqual(title.label, "Metal • $40")
        attach("stagger-retarget-settled", app)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

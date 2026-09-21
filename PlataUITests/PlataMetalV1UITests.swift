import XCTest

final class PlataMetalV1UITests: XCTestCase {
    @MainActor
    func testResourcesPosesAndTwoAxisRotation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--plata-metal-v1-demo"]
        app.launch()
        let scene = app.otherElements["plata-metal-v1-scene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 10))
        let ready = NSPredicate(format: "value BEGINSWITH %@", "Ready;")
        expectation(for: ready, evaluatedWith: scene)
        waitForExpectations(timeout: 60)

        for pose in ["front", "frontGrazing", "back", "edge"] {
            app.buttons["plata-metal-v1-\(pose)"].tap()
            // Allow the renderer to present the requested pose before capturing it.
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            XCTAssertTrue((scene.value as? String)?.hasPrefix("Ready;") == true)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "plata-metal-v1-\(pose)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.buttons["plata-metal-v1-front"].tap()
        XCTAssertEqual(scene.value as? String, "Ready; yaw 0; pitch 0; zoom 1.00; finish plata")
        scene.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: scene.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
        XCTAssertNotEqual(scene.value as? String, "Ready; yaw 0; pitch 0; zoom 1.00; finish plata")
        XCTAssertTrue((scene.value as? String)?.contains("; pitch 0;") == true)
        app.buttons["plata-metal-v1-front"].tap()
        XCTAssertEqual(scene.value as? String, "Ready; yaw 0; pitch 0; zoom 1.00; finish plata", "Same pose button must reset a dragged card")
        scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            .press(forDuration: 0.05, thenDragTo: scene.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)))
        XCTAssertTrue((scene.value as? String)?.hasPrefix("Ready; yaw 0;") == true)
        XCTAssertFalse((scene.value as? String)?.contains("; pitch 0;") == true)
        app.terminate()
    }
    @MainActor
    func testObsidianaFinishAndPinchZoom() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--plata-metal-v1-demo"]
        app.launch()
        let scene = app.otherElements["plata-metal-v1-scene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "Ready;"), evaluatedWith: scene)
        waitForExpectations(timeout: 60)
        let picker = app.segmentedControls["plata-metal-finish-picker"]
        picker.buttons["Obsidiana"].tap()
        XCTAssertTrue(scene.label.contains("Obsidiana"))
        XCTAssertTrue((scene.value as? String)?.hasSuffix("finish obsidiana") == true)
        XCTAssertEqual(app.staticTexts["plata-metal-demo-subtitle"].label,
                       "Obsidiana—matte PVD, dark to the edge")
        for pose in ["front", "frontGrazing", "back", "edge"] {
            app.buttons["plata-metal-v1-\(pose)"].tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.6))
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "obsidiana-\(pose)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app.buttons["plata-metal-v1-front"].tap()
        scene.pinch(withScale: 2, velocity: 0.7)
        let zoomed = scene.value as? String ?? ""
        XCTAssertTrue(zoomed.hasPrefix("Ready; yaw 0; pitch 0;"), "Pinch must not rotate the card")
        XCTAssertFalse(zoomed.contains("zoom 1.00"), "Pinch must magnify the geometry")
        let closeup = XCTAttachment(screenshot: app.screenshot())
        closeup.name = "obsidiana-zoom"
        closeup.lifetime = .keepAlways
        add(closeup)
        // Changing the finish keeps the current pose and magnification for direct comparison.
        picker.buttons["Plata"].tap()
        XCTAssertTrue(scene.label.contains("Plata"))
        XCTAssertEqual(scene.value as? String, zoomed.replacingOccurrences(of: "obsidiana", with: "plata"))
        scene.doubleTap()
        XCTAssertEqual(scene.value as? String, "Ready; yaw 0; pitch 0; zoom 1.00; finish plata")
        // The original drag interaction still works after switching and pinching.
        scene.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: scene.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
        XCTAssertFalse((scene.value as? String)?.hasPrefix("Ready; yaw 0;") == true)
        app.terminate()
    }

}

import XCTest
import Vision

final class PlataPlasticV1UITests: XCTestCase {
    @MainActor private func ready(_ scene: XCUIElement, skin: String) {
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "Ready; skin \(skin);"), evaluatedWith: scene)
        waitForExpectations(timeout: 60)
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func lines(_ app: XCUIApplication) throws -> [String] {
        let image = try XCTUnwrap(app.screenshot().image.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.minimumTextHeight = 0
        request.recognitionLanguages = ["en-US"]; request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        // Keep full-frame orientation inference, then discard status bar/UI OCR.
        let scene = app.otherElements["plata-plastic-scene"].frame
        let bounds = app.frame
        let roi = CGRect(x: scene.minX / bounds.width, y: 1 - scene.maxY / bounds.height,
                         width: scene.width / bounds.width, height: scene.height / bounds.height)
        return (request.results ?? []).filter { roi.contains(CGPoint(x: $0.boundingBox.midX, y: $0.boundingBox.midY)) }
            .compactMap { $0.topCandidates(1).first?.string }
    }
    @MainActor func testFiveFinishesBackAndLighting() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--plata-metal-v1-demo", "--plata-plastic-default"]
        app.launch()
        let scene = app.otherElements["plata-plastic-scene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 10))
        for skin in ["plata", "rose", "barro", "cobalto", "hueso"] {
            app.buttons["plata-plastic-skin-\(skin)"].tap(); ready(scene, skin: skin)
            for pose in ["front", "frontGrazing", "back", "edge"] {
                app.buttons["plata-plastic-pose-\(pose)"].tap()
                capture(app, "plastic-\(skin)-\(pose)")
                if pose == "front" {
                    let text = try lines(app).joined(separator: " ")
                    XCTAssertTrue(text.contains("SANTIAGO D FERNANDEZ"), text)
                    XCTAssertFalse(text.contains("CARD HOLDER"), text)
                }
                if pose == "back" {
                    let observed = try lines(app)
                    let text = observed.joined(separator: " ")
                    XCTAssertTrue(text.contains("Expire"), text)
                    XCTAssertTrue(text.contains("00/00"), text)
                    XCTAssertFalse(text.contains("CARD HOLDER"), text)
                    XCTAssertFalse(text.contains("SANTIAGO D FERNANDEZ"), text)
                    let pan = observed.filter { $0.range(of: #"^\d{4}(?:\s+\d{4})*$"#, options: .regularExpression) != nil }.joined().filter(\.isNumber)
                    XCTAssertEqual(pan, "0000000000000000", text)
                    // Metal-sized security captions are deliberately small at fit scale.
                    // Check the actual rendered print at native 2× camera zoom, not an upscaled bitmap.
                    scene.pinch(withScale: 2, velocity: 1)
                    capture(app, "plastic-\(skin)-security-code-2x")
                    let closeup = try lines(app).joined(separator: " ")
                    XCTAssertTrue(closeup.localizedCaseInsensitiveContains("CVV"), closeup)
                    app.buttons["plata-plastic-pose-back"].tap()
                }
            }
            app.buttons["plata-plastic-pose-frontGrazing"].tap()
            scene.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).press(forDuration: 0.05,
                thenDragTo: scene.coordinate(withNormalizedOffset: .init(dx: 0.58, dy: 0.54)))
            for light in ["Soft", "Night", "Studio"] {
                app.segmentedControls["plata-plastic-light"].buttons[light].tap()
                capture(app, "plastic-\(skin)-\(light.lowercased())")
            }
        }
        app.segmentedControls["plata-card-collection"].buttons["Metal"].tap()
        XCTAssertTrue(app.otherElements["plata-metal-v1-scene"].waitForExistence(timeout: 10))
        app.terminate()
    }
    @MainActor func testZoomAndPersonalization() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--plata-metal-v1-demo", "--plata-plastic-default"]
        app.launch()
        let scene = app.otherElements["plata-plastic-scene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 10)); ready(scene, skin: "plata")
        app.buttons["plata-plastic-pose-front"].tap()
        scene.pinch(withScale: 3.5, velocity: 0.8)
        XCTAssertTrue((scene.value as? String)?.contains("zoom 3.00") == true)
        for skin in ["plata", "rose", "barro", "cobalto", "hueso"] {
            app.buttons["plata-plastic-skin-\(skin)"].tap(); ready(scene, skin: skin)
            capture(app, "plastic-\(skin)-zoom-3x")
        }
        scene.doubleTap()
        XCTAssertTrue((scene.value as? String)?.contains("zoom 1.00") == true)
        scene.coordinate(withNormalizedOffset: .init(dx: 0.3, dy: 0.5)).press(forDuration: 0.05,
            thenDragTo: scene.coordinate(withNormalizedOffset: .init(dx: 0.7, dy: 0.5)))
        XCTAssertFalse((scene.value as? String)?.contains("yaw 0;") == true)
        app.buttons["plata-plastic-details"].tap()
        let field = app.textFields["plata-plastic-name-field"]
        field.tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + "MARIA FERNANDA GARCIA LOPEZ")
        app.buttons["plata-plastic-details-done"].tap(); ready(scene, skin: "hueso")
        app.buttons["plata-plastic-pose-front"].tap()
        capture(app, "plastic-hueso-long-name")
        app.buttons["plata-plastic-details"].tap()
        app.switches["plata-plastic-show-name"].coordinate(withNormalizedOffset: .init(dx: 0.92, dy: 0.5)).tap()
        app.switches["plata-plastic-show-number"].coordinate(withNormalizedOffset: .init(dx: 0.92, dy: 0.5)).tap()
        app.buttons["plata-plastic-details-done"].tap(); ready(scene, skin: "hueso")
        capture(app, "plastic-hueso-name-hidden")
        app.buttons["plata-plastic-pose-back"].tap()
        capture(app, "plastic-hueso-details-hidden")
        let text = try lines(app).joined(separator: " ")
        for hidden in ["CVV", "Expire", "0000", "00/00", "CARD HOLDER"] { XCTAssertFalse(text.contains(hidden), text) }
        XCTAssertTrue((scene.value as? String)?.contains("name hidden; number hidden") == true)
        app.terminate()
    }
}

import XCTest
import Vision

final class PlataDigitalV1UITests: XCTestCase {
    @MainActor private func ready(_ scene: XCUIElement, skin: String) {
        expectation(for: NSPredicate(format: "value BEGINSWITH %@", "Ready; skin \(skin);"), evaluatedWith: scene)
        waitForExpectations(timeout: 60)
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func cardText(_ app: XCUIApplication) throws -> String {
        let image = try XCTUnwrap(app.screenshot().image.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.minimumTextHeight = 0
        request.recognitionLanguages = ["en-US"]; request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: image).perform([request])
        let scene = app.otherElements["plata-digital-scene"].frame, bounds = app.frame
        let roi = CGRect(x: scene.minX / bounds.width, y: 1 - scene.maxY / bounds.height,
                         width: scene.width / bounds.width, height: scene.height / bounds.height)
        return (request.results ?? []).filter { roi.contains(CGPoint(x: $0.boundingBox.midX, y: $0.boundingBox.midY)) }
            .compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }
    @MainActor func testFourSkinsWithoutPersonalData() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--plata-metal-v1-demo", "--plata-digital-default"]
        app.launch()
        let scene = app.otherElements["plata-digital-scene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["plata-digital-details"].exists)
        for skin in ["amanecer", "jacaranda", "cenote", "noche"] {
            app.buttons["plata-digital-skin-\(skin)"].tap(); ready(scene, skin: skin)
            for pose in ["front", "frontGrazing", "back"] {
                app.buttons["plata-digital-pose-\(pose)"].tap()
                capture(app, "digital-clean-\(skin)-\(pose)")
                let text = try cardText(app)
                for removed in ["CARD HOLDER", "ALEX SMITH", "0000", "00/00", "Expire", "CVV", "Details hidden"] {
                    XCTAssertFalse(text.localizedCaseInsensitiveContains(removed), text)
                }
                if pose == "back" { XCTAssertTrue(text.isEmpty, "Digital back must contain only its artwork: \(text)") }
            }
            for light in ["Soft", "Night", "Studio"] {
                app.segmentedControls["plata-digital-light"].buttons[light].tap()
                capture(app, "digital-clean-\(skin)-back-\(light.lowercased())")
            }
        }
        app.segmentedControls["plata-card-collection"].buttons["Metal"].tap()
        XCTAssertTrue(app.otherElements["plata-metal-v1-scene"].waitForExistence(timeout: 10))
        app.terminate()
    }
    @MainActor func testZoomRotationAndSkinChange() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--plata-metal-v1-demo", "--plata-digital-default"]
        app.launch()
        let scene = app.otherElements["plata-digital-scene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 10)); ready(scene, skin: "amanecer")
        app.buttons["plata-digital-pose-front"].tap()
        scene.pinch(withScale: 3.5, velocity: 0.8)
        XCTAssertTrue((scene.value as? String)?.contains("yaw 0; pitch 0; zoom 3.00") == true)
        for skin in ["amanecer", "jacaranda", "cenote", "noche"] {
            app.buttons["plata-digital-skin-\(skin)"].tap(); ready(scene, skin: skin)
            XCTAssertTrue((scene.value as? String)?.contains("zoom 3.00") == true)
            capture(app, "digital-clean-\(skin)-zoom-3x")
        }
        scene.doubleTap()
        XCTAssertTrue((scene.value as? String)?.contains("zoom 1.00") == true)
        scene.coordinate(withNormalizedOffset: .init(dx: 0.3, dy: 0.5)).press(forDuration: 0.05,
            thenDragTo: scene.coordinate(withNormalizedOffset: .init(dx: 0.7, dy: 0.5)))
        XCTAssertFalse((scene.value as? String)?.contains("yaw 0;") == true)
        app.buttons["plata-digital-pose-edge"].tap()
        capture(app, "digital-clean-noche-edge")
        app.terminate()
    }
}

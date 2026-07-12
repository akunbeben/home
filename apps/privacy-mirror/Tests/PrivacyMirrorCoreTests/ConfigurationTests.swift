import Foundation
import XCTest
@testable import PrivacyMirrorCore

final class ConfigurationTests: XCTestCase {
    func testDecodesConfiguration() throws {
        let data = Data(#"{"excludedWorkspaces":["4","8"],"placeholderStyle":"solid","showsCursor":true,"captureFrameRate":24,"captureMaxWidth":2560,"shortcuts":{"reloadConfiguration":"option+shift+r","showOutput":"option+shift+s","parkOutput":"option+shift+p"}}"#.utf8)

        let configuration = try AppConfiguration.decode(data)

        XCTAssertEqual(configuration.excludedWorkspaces, ["4", "8"])
        XCTAssertEqual(configuration.placeholderStyle, .solid)
        XCTAssertTrue(configuration.showsCursor)
        XCTAssertEqual(configuration.captureFrameRate, 24)
        XCTAssertEqual(configuration.captureMaxWidth, 2560)
        XCTAssertEqual(configuration.shortcuts.showOutput, "option+shift+s")
    }

    func testDefaultsCursorCaptureOffAndLimitsCaptureCost() throws {
        let data = Data(#"{"excludedWorkspaces":["4"],"placeholderStyle":"blur"}"#.utf8)

        let configuration = try AppConfiguration.decode(data)

        XCTAssertFalse(configuration.showsCursor)
        XCTAssertEqual(configuration.captureFrameRate, 10)
        XCTAssertEqual(configuration.captureMaxWidth, 1920)
        XCTAssertEqual(configuration.shortcuts.reloadConfiguration, "option+shift+r")
        XCTAssertEqual(configuration.shortcuts.showOutput, "option+shift+s")
        XCTAssertEqual(configuration.shortcuts.parkOutput, "option+shift+p")
    }

    func testRejectsInvalidCaptureFrameRate() {
        let data = Data(#"{"excludedWorkspaces":["4"],"placeholderStyle":"blur","captureFrameRate":0}"#.utf8)

        XCTAssertThrowsError(try AppConfiguration.decode(data))
    }

    func testRejectsInvalidCaptureMaxWidth() {
        let data = Data(#"{"excludedWorkspaces":["4"],"placeholderStyle":"blur","captureMaxWidth":320}"#.utf8)

        XCTAssertThrowsError(try AppConfiguration.decode(data))
    }

    func testRejectsEmptyWorkspaceList() {
        let data = Data(#"{"excludedWorkspaces":[],"placeholderStyle":"blur"}"#.utf8)

        XCTAssertThrowsError(try AppConfiguration.decode(data))
    }

    func testDecodesAeroSpaceWindowIDs() throws {
        let data = Data(#"[{"window-id":7529},{"window-id":8515}]"#.utf8)

        XCTAssertEqual(try AeroSpaceClient.decodeWindowIDs(data), Set([7529, 8515]))
    }

    func testDecodesRelevantAeroSpaceEvents() {
        let workspace = Data(#"{"_event":"focused-workspace-changed","workspace":"4"}"#.utf8)
        let moveBinding = Data(#"{"_event":"binding-triggered","binding":"alt-shift-4"}"#.utf8)
        let focusBinding = Data(#"{"_event":"binding-triggered","binding":"alt-h"}"#.utf8)
        let screenshotBinding = Data(#"{"_event":"binding-triggered","binding":"alt-shift-p"}"#.utf8)

        XCTAssertEqual(AeroSpaceSubscription.decodeEvent(workspace), .stateChanged)
        XCTAssertEqual(AeroSpaceSubscription.decodeEvent(moveBinding), .windowMoveBinding)
        XCTAssertNil(AeroSpaceSubscription.decodeEvent(focusBinding))
        XCTAssertNil(AeroSpaceSubscription.decodeEvent(screenshotBinding))
    }

    func testCaptureGateRejectsStaleClassification() {
        var gate = CaptureGate()
        let stale = gate.invalidate()
        let current = gate.invalidate()

        XCTAssertFalse(gate.isOpen)
        XCTAssertFalse(gate.open(ifCurrent: stale))
        XCTAssertFalse(gate.isOpen)
        XCTAssertTrue(gate.open(ifCurrent: current))
        XCTAssertTrue(gate.isOpen)
        gate.invalidate()
        XCTAssertFalse(gate.isOpen)
    }

    func testPlaceholderFramesFlipScreenCaptureCoordinates() {
        let frames = PlaceholderLayout.frames(
            for: [CGRect(x: 100, y: 100, width: 300, height: 200)],
            displayFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            viewBounds: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )

        XCTAssertEqual(frames, [CGRect(x: 100, y: 500, width: 300, height: 200)])
    }

    func testPlaceholderFramesRespectAspectFitOffset() {
        let frames = PlaceholderLayout.frames(
            for: [CGRect(x: 0, y: 0, width: 1000, height: 800)],
            displayFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            viewBounds: CGRect(x: 0, y: 0, width: 1200, height: 800)
        )

        XCTAssertEqual(frames, [CGRect(x: 100, y: 0, width: 1000, height: 800)])
    }
}

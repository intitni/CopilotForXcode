import Foundation
import XCTest

@testable import LaunchAgentManager

final class DebugLaunchAgentPlistTests: XCTestCase {
    func test_xmlData_roundTripsProgramPathContainingAmpersand() throws {
        let programPath = "/tmp/foo & bar/CommunicationBridge"
        let data = try DebugLaunchAgentPlist.xmlData(
            serviceIdentifier: "dev.com.intii.CopilotForXcode.CommunicationBridge",
            programPath: programPath,
            bundleIdentifier: "dev.com.intii.CopilotForXcode"
        )

        let xml = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(xml.contains("&amp;"), "ampersand in the program path must be XML-escaped")
        XCTAssertFalse(xml.contains("foo & bar"))

        let parsed = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let dict = try XCTUnwrap(parsed as? [String: Any])
        XCTAssertEqual(dict["Program"] as? String, programPath)
        XCTAssertEqual(
            dict["Label"] as? String,
            "dev.com.intii.CopilotForXcode.CommunicationBridge"
        )
    }

    func test_propertyListsEqual_comparesParsedDictionaries() throws {
        let first = try DebugLaunchAgentPlist.xmlData(
            serviceIdentifier: "label",
            programPath: "/tmp/foo & bar",
            bundleIdentifier: "bundle"
        )
        let second = try DebugLaunchAgentPlist.xmlData(
            serviceIdentifier: "label",
            programPath: "/tmp/foo & bar",
            bundleIdentifier: "bundle"
        )
        XCTAssertTrue(DebugLaunchAgentPlist.propertyListsEqual(first, second))

        let different = try DebugLaunchAgentPlist.xmlData(
            serviceIdentifier: "label",
            programPath: "/tmp/other",
            bundleIdentifier: "bundle"
        )
        XCTAssertFalse(DebugLaunchAgentPlist.propertyListsEqual(first, different))
    }
}

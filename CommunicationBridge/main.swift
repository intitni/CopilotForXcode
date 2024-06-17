import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {}

let bundleIdentifierBase = Bundle(url: Bundle.main.bundleURL.appendingPathComponent(
    "CopilotForXcodeExtensionService.app"
))?.object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as? String ?? "com.intii.CopilotForXcode"

let serviceIdentifier = bundleIdentifierBase + ".CommunicationBridge"
let appDelegate = AppDelegate()
let delegate = ServiceDelegate()
let listener = NSXPCListener(machServiceName: serviceIdentifier)
listener.delegate = delegate
listener.resume()
let app = NSApplication.shared
app.delegate = appDelegate
app.run()


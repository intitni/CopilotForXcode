import Foundation

let bundleIdentifierBase = Bundle(url: Bundle.main.bundleURL.appendingPathComponent(
    "CopilotForXcodeExtensionService.app"
))?.object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as? String ?? "com.intii.CopilotForXcode"

let serviceIdentifier = bundleIdentifierBase + ".CommunicationBridge"

let delegate = ServiceDelegate()
let listener = NSXPCListener(machServiceName: serviceIdentifier)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()


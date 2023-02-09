import AppKit
import Foundation
import LaunchAgentManager
import os.log
import Service

let bundleIdentifierBase = Bundle.main
    .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String

let serviceIdentifier = bundleIdentifierBase + ".XPCService"

func setupXPCListener() -> (NSXPCListener, ServiceDelegate) {
    let listener = NSXPCListener(machServiceName: serviceIdentifier)
    let delegate = ServiceDelegate()
    listener.delegate = delegate
    listener.resume()
    return (listener, delegate)
}

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
let xpcListener = setupXPCListener()
os_log(.info, "XPC Service started.")
app.run()

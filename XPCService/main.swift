import Foundation

let listener = NSXPCListener(
    machServiceName: Bundle.main.object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String
        + ".XPCService"
)
let delegate = ServiceDelegate()
listener.delegate = delegate
listener.resume()
RunLoop.main.run()

import Foundation
import Service

let listener = NSXPCListener(
    machServiceName: Bundle.main.object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String
        + ".XPCService"
)
let delegate = ServiceDelegate()
listener.delegate = delegate
listener.resume()
_ = AutoTrigger.shared
RunLoop.main.run()

import Client
import CopilotModel
import Foundation
import XcodeKit

class SeparatorCommand: NSObject, XCSourceEditorCommand, CommandType {
    let name: String
    
    init(_ name: String) {
        self.name = name
    }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
    }
}

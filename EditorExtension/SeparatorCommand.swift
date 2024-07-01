import Client
import SuggestionBasic
import Foundation
import XcodeKit

class SeparatorCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String = ""
    
    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
    }
    
    func named(_ name: String) -> Self {
        self.name = name
        return self
    }
}

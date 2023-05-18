import Client
import Foundation
import SuggestionModel
import XcodeKit

class CustomCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String = ""

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.customCommand(
                id: customCommandMap[invocation.commandIdentifier] ?? "",
                editorContent: .init(invocation)
            )
        }
    }
}


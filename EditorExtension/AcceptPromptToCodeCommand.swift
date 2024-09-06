import Client
import Foundation
import SuggestionBasic
import XcodeKit

class AcceptPromptToCodeCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Accept Modification" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                try await (Task(timeout: 7) {
                    let service = try getService()
                    if let content = try await service.getPromptToCodeAcceptedCode(
                        editorContent: .init(invocation)
                    ) {
                        invocation.accept(content)
                    }
                    completionHandler(nil)
                }.value)
            } catch is CancellationError {
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}

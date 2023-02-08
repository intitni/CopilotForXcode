import Client
import CopilotModel
import Foundation
import XcodeKit

class ToggleRealtimeSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Toggle Real-time Suggestions" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                try await service.setAutoSuggestion(enabled: true)
                completionHandler(nil)
            } catch is CancellationError {
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}

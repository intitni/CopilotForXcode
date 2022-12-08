import Client
import CopilotModel
import Foundation
import XcodeKit

class TurnOnRealtimeSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Turn On Realtime Suggestions" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                try await service.setAutoSuggestion(enabled: true)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}

import Client
import CopilotModel
import Foundation
import XcodeKit

class TurnOffRealtimeSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Turn Off Realtime Suggestions for Workpace" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                try await service.setAutoSuggestion(enabled: false)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}

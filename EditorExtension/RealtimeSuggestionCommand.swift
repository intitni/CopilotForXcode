import Client
import CopilotModel
import Foundation
import XcodeKit

class RealtimeSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Real-time Suggestions" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        switch UserDefaults.shared.value(for: \.suggestionPresentationMode) {
        case .comment:
            Task {
                do {
                    let service = try getService()
                    if let content = try await service.getRealtimeSuggestedCode(
                        editorContent: .init(invocation)
                    ) {
                        invocation.accept(content)
                    }
                    completionHandler(nil)
                } catch is CancellationError {
                    completionHandler(nil)
                } catch {
                    completionHandler(error)
                }
            }
        case .floatingWidget:
            completionHandler(nil)
            Task {
                let service = try getService()
                _ = try await service.getRealtimeSuggestedCode(editorContent: .init(invocation))
            }
        }
    }
}

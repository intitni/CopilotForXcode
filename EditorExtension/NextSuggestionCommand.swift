import Client
import Foundation
import SuggestionModel
import XcodeKit

class NextSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Next Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        switch UserDefaults.shared.value(for: \.suggestionPresentationMode) {
        case .comment:
            Task {
                do {
                    try await (Task(timeout: 7) {
                        let service = try getService()
                        if let content = try await service.getNextSuggestedCode(
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
        case .floatingWidget:
            completionHandler(nil)
            Task {
                let service = try getService()
                _ = try await service.getNextSuggestedCode(editorContent: .init(invocation))
            }
        }
    }
}


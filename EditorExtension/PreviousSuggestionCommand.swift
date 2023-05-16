import Client
import Foundation
import SuggestionModel
import XcodeKit

class PreviousSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Previous Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        switch UserDefaults.shared.value(for: \.suggestionPresentationMode) {
        case .comment:
            Task {
                do {
                    let service = try getService()
                    if let content = try await service.getPreviousSuggestedCode(
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
                _ = try await service.getPreviousSuggestedCode(editorContent: .init(invocation))
            }
        }
    }
}


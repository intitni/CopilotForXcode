import Client
import Foundation
import SuggestionModel
import XcodeKit

class GetSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Get Suggestions" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        switch UserDefaults.shared.value(for: \.suggestionPresentationMode) {
        case .comment:
            Task {
                do {
                    let service = try getService()
                    if let content = try await service.getSuggestedCode(
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
                _ = try await service.getSuggestedCode(editorContent: .init(invocation))
            }
        }
    }
}


import Client
import SuggestionBasic
import Foundation
import XcodeKit

class PrefetchSuggestionsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Prefetch Suggestions" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            await service.prefetchRealtimeSuggestions(editorContent: .init(invocation))
        }
    }
}

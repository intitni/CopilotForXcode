import Client
import Foundation
import SuggestionBasic
import XcodeKit

class CloseIdleTabsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Close Idle Tabs" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.postNotification(name: "CloseIdleTabsOfXcodeWindow")
        }
    }
}


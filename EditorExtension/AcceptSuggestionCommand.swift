import Client
import Foundation
import SuggestionBasic
import XcodeKit
import XPCShared

class AcceptSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Accept Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                try await (Task(timeout: 7) {
                    let service = try getService()
                    if let content = try await service.getSuggestionAcceptedCode(
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

class AcceptSuggestionLineCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Accept Suggestion Line" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                try await (Task(timeout: 7) {
                    let service = try getService()
                    if let content = try await service.send(
                        requestBody: ExtensionServiceRequests
                            .GetSuggestionLineAcceptedCode(editorContent: .init(invocation))
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

import AppKit
import Environment
import Foundation
import GitHubCopilotService
import LanguageServerProtocol
import Logger
import Preferences
import XPCShared

@globalActor public enum ServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

@ServiceActor
var workspaces = [URL: Workspace]()

public class XPCService: NSObject, XPCServiceProtocol {
    // MARK: - Service

    public func getXPCServiceVersion(withReply reply: @escaping (String, String) -> Void) {
        reply(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A",
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
        )
    }

    public func getXPCServiceAccessibilityPermission(withReply reply: @escaping (Bool) -> Void) {
        reply(AXIsProcessTrusted())
    }

    // MARK: - Suggestion

    @discardableResult
    private func replyWithUpdatedContent(
        editorContent: Data,
        file: StaticString = #file,
        line: UInt = #line,
        isRealtimeSuggestionRelatedCommand: Bool = false,
        withReply reply: @escaping (Data?, Error?) -> Void,
        getUpdatedContent: @escaping @ServiceActor (
            SuggestionCommandHandler,
            EditorContent
        ) async throws -> UpdatedContent?
    ) -> Task<Void, Never> {
        let task = Task {
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let mode = UserDefaults.shared.value(for: \.suggestionPresentationMode)
                let handler: SuggestionCommandHandler = {
                    switch mode {
                    case .comment:
                        return CommentBaseCommandHandler()
                    case .floatingWidget:
                        return WindowBaseCommandHandler()
                    }
                }()
                try Task.checkCancellation()
                guard let updatedContent = try await getUpdatedContent(handler, editor) else {
                    reply(nil, nil)
                    return
                }
                try Task.checkCancellation()
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                Logger.service.error("\(file):\(line) \(error.localizedDescription)")
                reply(nil, NSError.from(error))
            }
        }

        Task {
            await RealtimeSuggestionController.shared.cancelInFlightTasks(excluding: task)
        }
        return task
    }

    public func getSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentSuggestions(editor: editor)
        }
    }

    public func getNextSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentNextSuggestion(editor: editor)
        }
    }

    public func getPreviousSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentPreviousSuggestion(editor: editor)
        }
    }

    public func getSuggestionRejectedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.rejectSuggestion(editor: editor)
        }
    }

    public func getSuggestionAcceptedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.acceptSuggestion(editor: editor)
        }
    }

    public func getRealtimeSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(
            editorContent: editorContent,
            isRealtimeSuggestionRelatedCommand: true,
            withReply: reply
        ) { handler, editor in
            try await handler.presentRealtimeSuggestions(editor: editor)
        }
    }

    public func prefetchRealtimeSuggestions(
        editorContent: Data,
        withReply reply: @escaping () -> Void
    ) {
        // We don't need to wait for this.
        reply()

        replyWithUpdatedContent(
            editorContent: editorContent,
            isRealtimeSuggestionRelatedCommand: true,
            withReply: { _, _ in }
        ) { handler, editor in
            try await handler.generateRealtimeSuggestions(editor: editor)
        }
    }

    public func chatWithSelection(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.chatWithSelection(editor: editor)
        }
    }

    public func promptToCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.promptToCode(editor: editor)
        }
    }

    public func customCommand(
        id: String,
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.customCommand(id: id, editor: editor)
        }
    }

    // MARK: - Settings

    public func toggleRealtimeSuggestion(withReply reply: @escaping (Error?) -> Void) {
        guard AXIsProcessTrusted() else {
            reply(NoAccessToAccessibilityAPIError())
            return
        }
        Task { @ServiceActor in
            await RealtimeSuggestionController.shared.cancelInFlightTasks()
            UserDefaults.shared.set(
                !UserDefaults.shared.value(for: \.realtimeSuggestionToggle),
                for: \.realtimeSuggestionToggle
            )
            reply(nil)
        }
    }
}


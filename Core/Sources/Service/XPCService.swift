import AppKit
import CopilotService
import Environment
import Foundation
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

#warning("TODO: Find a better place to store it!")
@ServiceActor
var inflightRealtimeSuggestionsTasks = Set<Task<Void, Never>>()

public class XPCService: NSObject, XPCServiceProtocol {
    // MARK: - Service

    public func getXPCServiceVersion(withReply reply: @escaping (String, String) -> Void) {
        reply(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A",
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
        )
    }

    // MARK: - Copilot Auth

    @ServiceActor
    lazy var authService: CopilotAuthServiceType = Environment.createAuthService()

    public func checkStatus(withReply reply: @escaping (String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let status = try await authService.checkStatus()
                reply(status.rawValue, nil)
            } catch {
                reply(nil, NSError.from(error))
            }
        }
    }

    public func signInInitiate(withReply reply: @escaping (String?, String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let (verificationLink, userCode) = try await authService.signInInitiate()
                reply(verificationLink, userCode, nil)
            } catch {
                reply(nil, nil, NSError.from(error))
            }
        }
    }

    public func signInConfirm(
        userCode: String,
        withReply reply: @escaping (String?, String?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let (username, status) = try await authService.signInConfirm(userCode: userCode)
                reply(username, status.rawValue, nil)
            } catch {
                reply(nil, nil, NSError.from(error))
            }
        }
    }

    public func getVersion(withReply reply: @escaping (String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let version = try await authService.version()
                reply(version, nil)
            } catch {
                reply(nil, NSError.from(error))
            }
        }
    }

    public func signOut(withReply reply: @escaping (String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let status = try await authService.signOut()
                reply(status.rawValue, nil)
            } catch {
                reply(nil, NSError.from(error))
            }
        }
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
        let task = replyWithUpdatedContent(
            editorContent: editorContent,
            isRealtimeSuggestionRelatedCommand: true,
            withReply: reply
        ) { handler, editor in
            try await handler.presentRealtimeSuggestions(editor: editor)
        }

        Task { @ServiceActor in inflightRealtimeSuggestionsTasks.insert(task) }
    }

    public func prefetchRealtimeSuggestions(
        editorContent: Data,
        withReply reply: @escaping () -> Void
    ) {
        // We don't need to wait for this.
        reply()

        let task = replyWithUpdatedContent(
            editorContent: editorContent,
            isRealtimeSuggestionRelatedCommand: true,
            withReply: { _, _ in }
        ) { handler, editor in
            try await handler.generateRealtimeSuggestions(editor: editor)
        }

        Task { @ServiceActor in inflightRealtimeSuggestionsTasks.insert(task) }
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

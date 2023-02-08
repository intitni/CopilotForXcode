import AppKit
import CopilotService
import Foundation
import LanguageServerProtocol
import os.log
import XPCShared

@globalActor enum ServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

@ServiceActor
var workspaces = [URL: Workspace]()
@ServiceActor
var inflightRealtimeSuggestionsTasks = Set<Task<Void, Never>>()

public class XPCService: NSObject, XPCServiceProtocol {
    public func getXPCServiceVersion(withReply reply: @escaping (String, String) -> Void) {
        reply(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A",
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A")
    }

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

    public func getSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                guard let updatedContent = try await workspace.getSuggestedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition,
                    tabSize: editor.tabSize,
                    indentSize: editor.indentSize,
                    usesTabsForIndentation: editor.usesTabsForIndentation
                ) else {
                    reply(nil, nil)
                    return
                }
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                os_log(.error, "%@", error.localizedDescription)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getNextSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                guard let updatedContent = workspace.getNextSuggestedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition
                ) else {
                    reply(nil, nil)
                    return
                }
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                os_log(.error, "%@", error.localizedDescription)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getPreviousSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                guard let updatedContent = workspace.getPreviousSuggestedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition
                ) else {
                    reply(nil, nil)
                    return
                }
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                os_log(.error, "%@", error.localizedDescription)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getSuggestionRejectedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                let updatedContent = workspace.getSuggestionRejectedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition
                )
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                os_log(.error, "%@", error.localizedDescription)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getSuggestionAcceptedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                guard let updatedContent = workspace.getSuggestionAcceptedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition
                ) else {
                    reply(nil, nil)
                    return
                }
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                os_log(.error, "%@", error.localizedDescription)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getRealtimeSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        let task = Task { @ServiceActor in
            do {
                try Task.checkCancellation()
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                try Task.checkCancellation()
                let fileURL = try await Environment.fetchCurrentFileURL()
                try Task.checkCancellation()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
                try Task.checkCancellation()
                guard let updatedContent = workspace.getRealtimeSuggestedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition,
                    tabSize: editor.tabSize,
                    indentSize: editor.indentSize,
                    usesTabsForIndentation: editor.usesTabsForIndentation
                ) else {
                    reply(nil, nil)
                    return
                }
                try Task.checkCancellation()
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                os_log(.error, "%@", error.localizedDescription)
                reply(nil, NSError.from(error))
            }
        }
        
        Task { @ServiceActor in inflightRealtimeSuggestionsTasks.insert(task) }
    }

    public func setAutoSuggestion(enabled: Bool, withReply reply: @escaping (Error?) -> Void) {
        guard AXIsProcessTrusted() else {
            reply(NoAccessToAccessibilityAPIError())
            return
        }
        Task { @ServiceActor in
            UserDefaults.shared.set(
                enabled,
                forKey: SettingsKey.realtimeSuggestionToggle
            )
            reply(nil)
        }
    }

    public func prefetchRealtimeSuggestions(
        editorContent: Data,
        withReply reply: @escaping () -> Void
    ) {
        let task = Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
                try Task.checkCancellation()
                _ = workspace.getRealtimeSuggestedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition,
                    tabSize: editor.tabSize,
                    indentSize: editor.indentSize,
                    usesTabsForIndentation: editor.usesTabsForIndentation
                )
                reply()
            } catch {
                os_log(.error, "%@", error.localizedDescription)
                reply()
            }
        }
        
        Task { @ServiceActor in inflightRealtimeSuggestionsTasks.insert(task) }
    }
}

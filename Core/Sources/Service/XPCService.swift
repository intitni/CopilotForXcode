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
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
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
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                os_log(.error, "%@", error.localizedDescription)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func setAutoSuggestion(enabled: Bool, withReply reply: @escaping (Error?) -> Void) {
        struct NoInputMonitoringPermission: Error, LocalizedError {
            var errorDescription: String? {
                "Permission for Input Monitoring is not granted to make real-time suggestions work. Please turn in on in System Settings.app and try again later."
            }
        }
        guard AXIsProcessTrusted() else {
            reply(NoInputMonitoringPermission())
            return
        }
        Task { @ServiceActor in
            let fileURL = try await Environment.fetchCurrentFileURL()
            let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
            if var state = UserDefaults.shared
                .dictionary(forKey: SettingsKey.realtimeSuggestionState)
            {
                state[workspace.projectRootURL.absoluteString] = enabled
                UserDefaults.shared.set(state, forKey: SettingsKey.realtimeSuggestionState)
            } else {
                UserDefaults.shared.set(
                    [workspace.projectRootURL.absoluteString: enabled],
                    forKey: SettingsKey.realtimeSuggestionState
                )
            }
            reply(nil)
        }
    }

    public func prefetchRealtimeSuggestions(
        editorContent: Data,
        withReply reply: @escaping () -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
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
    }
}

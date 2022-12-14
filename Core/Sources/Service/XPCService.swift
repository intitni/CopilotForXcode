import AppKit
import CopilotService
import Foundation
import LanguageServerProtocol
import XPCShared

@globalActor enum ServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

@ServiceActor
var workspaces = [URL: Workspace]()

public class XPCService: NSObject, XPCServiceProtocol {
    @ServiceActor
    lazy var authService: CopilotAuthServiceType = Environment.createAuthService()

    override public init() {
        super.init()
        let identifier = ObjectIdentifier(self)
        Task {
            await AutoTrigger.shared.start(by: identifier)
        }
    }

    deinit {
        let identifier = ObjectIdentifier(self)
        Task {
            await AutoTrigger.shared.stop(by: identifier)
        }
    }

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

    public func signInConfirm(userCode: String, withReply reply: @escaping (String?, String?, Error?) -> Void) {
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
                print(error)
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
                print(error)
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
                print(error)
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
                print(error)
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
                print(error)
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
                print(error)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func setAutoSuggestion(enabled: Bool, withReply reply: @escaping (Error?) -> Void) {
        Task { @ServiceActor in
            let fileURL = try await Environment.fetchCurrentFileURL()
            let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
            workspace.isRealtimeSuggestionEnabled = enabled
            reply(nil)
        }
    }
}

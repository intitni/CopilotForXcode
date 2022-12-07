import AppKit
import CopilotService
import Foundation
import LanguageServerProtocol

@globalActor enum ServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

class XPCService: NSObject, XPCServiceProtocol {
    @ServiceActor
    lazy var authService: CopilotAuthServiceType = Environment.createAuthService()
    @ServiceActor
    var workspaces = [URL: Workspace]()

    func checkStatus(withReply reply: @escaping (String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let status = try await authService.checkStatus()
                reply(status.rawValue, nil)
            } catch {
                reply(nil, NSError.from(error))
            }
        }
    }

    func signInInitiate(withReply reply: @escaping (String?, String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let (verificationLink, userCode) = try await authService.signInInitiate()
                reply(verificationLink, userCode, nil)
            } catch {
                reply(nil, nil, NSError.from(error))
            }
        }
    }

    func signInConfirm(userCode: String, withReply reply: @escaping (String?, String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let (username, status) = try await authService.signInConfirm(userCode: userCode)
                reply(username, status.rawValue, nil)
            } catch {
                reply(nil, nil, NSError.from(error))
            }
        }
    }

    func getVersion(withReply reply: @escaping (String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let version = try await authService.version()
                reply(version, nil)
            } catch {
                reply(nil, NSError.from(error))
            }
        }
    }

    func signOut(withReply reply: @escaping (String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let status = try await authService.signOut()
                reply(status.rawValue, nil)
            } catch {
                reply(nil, NSError.from(error))
            }
        }
    }

    func getSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let projectURL = try await Environment.fetchCurrentProjectRootURL()
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspaceURL = projectURL ?? fileURL
                let workspace = workspaces[workspaceURL] ?? Workspace(projectRootURL: workspaceURL)
                workspaces[workspaceURL] = workspace
                let updatedContent = try await workspace.getSuggestedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition,
                    tabSize: editor.tabSize,
                    indentSize: editor.indentSize,
                    usesTabsForIndentation: editor.usesTabsForIndentation
                )
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                print(error)
                reply(nil, NSError.from(error))
            }
        }
    }

    func getNextSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let projectURL = try await Environment.fetchCurrentProjectRootURL()
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspaceURL = projectURL ?? fileURL
                let workspace = workspaces[workspaceURL] ?? Workspace(projectRootURL: workspaceURL)
                let updatedContent = workspace.getNextSuggestedCode(
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

    func getPreviousSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let projectURL = try await Environment.fetchCurrentProjectRootURL()
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspaceURL = projectURL ?? fileURL
                let workspace = workspaces[workspaceURL] ?? Workspace(projectRootURL: workspaceURL)
                let updatedContent = workspace.getPreviousSuggestedCode(
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

    func getSuggestionRejectedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let projectURL = try await Environment.fetchCurrentProjectRootURL()
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspaceURL = projectURL ?? fileURL
                let workspace = workspaces[workspaceURL] ?? Workspace(projectRootURL: workspaceURL)
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

    func getSuggestionAcceptedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let projectURL = try await Environment.fetchCurrentProjectRootURL()
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspaceURL = projectURL ?? fileURL
                let workspace = workspaces[workspaceURL] ?? Workspace(projectRootURL: workspaceURL)
                let updatedContent = workspace.getSuggestionAcceptedCode(
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
}

extension NSError {
    static func from(_ error: Error) -> NSError {
        if let error = error as? ServerError {
            var message = "Unknown"
            switch error {
            case let .handlerUnavailable(handler):
                message = "Handler unavailable: \(handler)."
            case let .unhandledMethod(method):
                message = "Methond unhandled: \(method)."
            case let .notificationDispatchFailed(error):
                message = "Notification dispatch failed: \(error.localizedDescription)."
            case let .requestDispatchFailed(error):
                message = "Request dispatch failed: \(error.localizedDescription)."
            case let .clientDataUnavailable(error):
                message = "Client data unavalable: \(error.localizedDescription)."
            case .serverUnavailable:
                message = "Server unavailable, please make sure you have installed Node."
            case .missingExpectedParameter:
                message = "Missing expected parameter."
            case .missingExpectedResult:
                message = "Missing expected result."
            case let .unableToDecodeRequest(error):
                message = "Unable to decode request: \(error.localizedDescription)."
            case let .unableToSendRequest(error):
                message = "Unable to send request: \(error.localizedDescription)."
            case let .unableToSendNotification(error):
                message = "Unable to send notification: \(error.localizedDescription)."
            case let .serverError(code, m, _):
                message = "Server error: (\(code)) \(m)."
            case let .invalidRequest(error):
                message = "Invalid request: \(error?.localizedDescription ?? "Unknown")."
            case .timeout:
                message = "Timeout."
            }
            return NSError(domain: "com.intii.CopilotForXcode", code: -1, userInfo: [
                NSLocalizedDescriptionKey: message,
            ])
        }
        return NSError(domain: "com.intii.CopilotForXcode", code: -1, userInfo: [
            NSLocalizedDescriptionKey: error.localizedDescription,
        ])
    }
}

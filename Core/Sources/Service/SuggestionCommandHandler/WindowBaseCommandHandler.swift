import CopilotModel
import CopilotService
import Environment
import Foundation
import Logger
import OpenAIService
import SuggestionInjector
import SuggestionWidget
import XPCShared

@ServiceActor
struct WindowBaseCommandHandler: SuggestionCommandHandler {
    nonisolated init() {}

    let presenter = PresentInWindowSuggestionPresenter()

    func presentSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _presentSuggestions(editor: editor)
            } catch {
                presenter.presentError(error)
                Logger.service.error(error)
            }
        }
        return nil
    }

    private func _presentSuggestions(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer {
            presenter.markAsProcessing(false)
        }
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

        try Task.checkCancellation()

        let snapshot = Filespace.Snapshot(
            linesHash: editor.lines.hashValue,
            cursorPosition: editor.cursorPosition
        )

        // There is no need to regenerate suggestions for the same editor content.
        guard filespace.suggestionSourceSnapshot != snapshot else { return }

        try await workspace.generateSuggestions(
            forFileAt: fileURL,
            editor: editor
        )

        if let suggestion = filespace.presentingSuggestion {
            presenter.presentSuggestion(
                suggestion,
                lines: editor.lines,
                language: filespace.language,
                fileURL: fileURL,
                currentSuggestionIndex: filespace.suggestionIndex,
                suggestionCount: filespace.suggestions.count
            )
        } else {
            presenter.discardSuggestion(fileURL: fileURL)
        }
    }

    func presentNextSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _presentNextSuggestion(editor: editor)
            } catch {
                presenter.presentError(error)
            }
        }
        return nil
    }

    private func _presentNextSuggestion(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.selectNextSuggestion(forFileAt: fileURL)

        if let suggestion = filespace.presentingSuggestion {
            presenter.presentSuggestion(
                suggestion,
                lines: editor.lines,
                language: filespace.language,
                fileURL: fileURL,
                currentSuggestionIndex: filespace.suggestionIndex,
                suggestionCount: filespace.suggestions.count
            )
        } else {
            presenter.discardSuggestion(fileURL: fileURL)
        }
    }

    func presentPreviousSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _presentPreviousSuggestion(editor: editor)
            } catch {
                presenter.presentError(error)
            }
        }
        return nil
    }

    private func _presentPreviousSuggestion(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.selectPreviousSuggestion(forFileAt: fileURL)

        if let suggestion = filespace.presentingSuggestion {
            presenter.presentSuggestion(
                suggestion,
                lines: editor.lines,
                language: filespace.language,
                fileURL: fileURL,
                currentSuggestionIndex: filespace.suggestionIndex,
                suggestionCount: filespace.suggestions.count
            )
        } else {
            presenter.discardSuggestion(fileURL: fileURL)
        }
    }

    func rejectSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _rejectSuggestion(editor: editor)
            } catch {
                presenter.presentError(error)
            }
        }
        return nil
    }

    private func _rejectSuggestion(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, _) = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.rejectSuggestion(forFileAt: fileURL, editor: editor)
        presenter.discardSuggestion(fileURL: fileURL)
    }

    func acceptSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }

        do {
            let result = try await CommentBaseCommandHandler().acceptSuggestion(editor: editor)
            Task {
                let fileURL = try await Environment.fetchCurrentFileURL()
                presenter.discardSuggestion(fileURL: fileURL)
            }
            return result
        } catch {
            presenter.presentError(error)
            throw error
        }
    }

    func presentRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        // not needed.
        return nil
    }

    func generateRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        return try await presentSuggestions(editor: editor)
    }

    func explainSelection(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _explainSelection(editor: editor)
            } catch {
                presenter.presentError(error)
            }
        }
        return nil
    }

    private func _explainSelection(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }

        let fileURL = try await Environment.fetchCurrentFileURL()
        let endpoint = UserDefaults.shared.value(for: \.chatGPTEndpoint)
        let model = UserDefaults.shared.value(for: \.chatGPTModel)
        let language = UserDefaults.shared.value(for: \.chatGPTLanguage)
        guard let selection = editor.selections.last else { return }

        let service = ChatGPTService(
            systemPrompt: """
            You are a code explanation engine, you can only explain the code, do not interpret or translate it. Reply in \(language.isEmpty ? language : "English")
            """,
            apiKey: UserDefaults.shared.value(for: \.openAIAPIKey),
            endpoint: endpoint.isEmpty ? nil : endpoint,
            model: model.isEmpty ? nil : model,
            temperature: 0.6,
            maxToken: UserDefaults.shared.value(for: \.chatGPTMaxToken)
        )

        let code = editor.selectedCode(in: selection)
        Task {
            try? await service.send(
                content: removeContinousSpaces(from: code),
                summary: "Explain selected code from \(selection.start.line):\(selection.start.character) to \(selection.end.line):\(selection.end.character)."
            )
        }

        presenter.presentChatGPTConversation(service, fileURL: fileURL)
    }
}

func removeContinousSpaces(from string: String) -> String {
    return string.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
}

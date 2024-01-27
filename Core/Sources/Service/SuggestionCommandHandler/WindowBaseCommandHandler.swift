import AppKit
import ChatService
import Foundation
import GitHubCopilotService
import LanguageServerProtocol
import Logger
import OpenAIService
import SuggestionInjector
import SuggestionModel
import SuggestionWidget
import UserNotifications
import Workspace
import WorkspaceSuggestionService
import XcodeInspector
import XPCShared

struct WindowBaseCommandHandler: SuggestionCommandHandler {
    nonisolated init() {}

    let presenter = PresentInWindowSuggestionPresenter()

    func presentSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _presentSuggestions(editor: editor)
            } catch let error as ServerError {
                Logger.service.error(error)
            } catch {
                presenter.presentError(error)
                Logger.service.error(error)
            }
        }
        return nil
    }

    @WorkspaceActor
    private func _presentSuggestions(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer {
            presenter.markAsProcessing(false)
        }
        guard let fileURL = XcodeInspector.shared.realtimeActiveDocumentURL else { return }
        let (workspace, filespace) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)

        try Task.checkCancellation()

        let snapshot = FilespaceSuggestionSnapshot(
            linesHash: editor.lines.hashValue,
            cursorPosition: editor.cursorPosition
        )

        // There is no need to regenerate suggestions for the same editor content.
        guard filespace.suggestionSourceSnapshot != snapshot else { return }

        try await workspace.generateSuggestions(
            forFileAt: fileURL,
            editor: editor
        )

        try Task.checkCancellation()

        if filespace.presentingSuggestion != nil {
            presenter.presentSuggestion(fileURL: fileURL)
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

    @WorkspaceActor
    private func _presentNextSuggestion(editor: EditorContent) async throws {
        guard let fileURL = XcodeInspector.shared.realtimeActiveDocumentURL else { return }
        let (workspace, filespace) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        workspace.selectNextSuggestion(forFileAt: fileURL)

        if filespace.presentingSuggestion != nil {
            presenter.presentSuggestion(fileURL: fileURL)
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

    @WorkspaceActor
    private func _presentPreviousSuggestion(editor: EditorContent) async throws {
        guard let fileURL = XcodeInspector.shared.realtimeActiveDocumentURL else { return }
        let (workspace, filespace) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        workspace.selectPreviousSuggestion(forFileAt: fileURL)

        if filespace.presentingSuggestion != nil {
            presenter.presentSuggestion(fileURL: fileURL)
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

    @WorkspaceActor
    private func _rejectSuggestion(editor: EditorContent) async throws {
        guard let fileURL = XcodeInspector.shared.realtimeActiveDocumentURL else { return }

        let (workspace, _) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        workspace.rejectSuggestion(forFileAt: fileURL, editor: editor)
        presenter.discardSuggestion(fileURL: fileURL)
    }

    @WorkspaceActor
    func acceptSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        guard let fileURL = XcodeInspector.shared.realtimeActiveDocumentURL else { return nil }
        let (workspace, _) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)

        let injector = SuggestionInjector()
        var lines = editor.lines
        var cursorPosition = editor.cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()

        if let acceptedSuggestion = workspace.acceptSuggestion(
            forFileAt: fileURL,
            editor: editor
        ) {
            injector.acceptSuggestion(
                intoContentWithoutSuggestion: &lines,
                cursorPosition: &cursorPosition,
                completion: acceptedSuggestion,
                extraInfo: &extraInfo
            )

            presenter.discardSuggestion(fileURL: fileURL)

            return .init(
                content: String(lines.joined(separator: "")),
                newSelection: .cursor(cursorPosition),
                modifications: extraInfo.modifications
            )
        }

        return nil
    }

    func acceptPromptToCode(editor: EditorContent) async throws -> UpdatedContent? {
        guard let fileURL = XcodeInspector.shared.realtimeActiveDocumentURL else { return nil }

        let injector = SuggestionInjector()
        var lines = editor.lines
        var cursorPosition = editor.cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()

        let viewStore = Service.shared.guiController.viewStore

        if let promptToCode = viewStore.state.promptToCodeGroup.activePromptToCode {
            if promptToCode.isAttachedToSelectionRange, promptToCode.documentURL != fileURL {
                return nil
            }

            let range = {
                if promptToCode.isAttachedToSelectionRange,
                   let range = promptToCode.selectionRange
                {
                    return range
                }
                return editor.selections.first.map {
                    CursorRange(start: $0.start, end: $0.end)
                } ?? CursorRange(
                    start: editor.cursorPosition,
                    end: editor.cursorPosition
                )
            }()

            let suggestion = CodeSuggestion(
                id: UUID().uuidString,
                text: promptToCode.code,
                position: range.start,
                range: range
            )

            injector.acceptSuggestion(
                intoContentWithoutSuggestion: &lines,
                cursorPosition: &cursorPosition,
                completion: suggestion,
                extraInfo: &extraInfo
            )

            _ = await Task { @MainActor [cursorPosition] in
                viewStore.send(
                    .promptToCodeGroup(.updatePromptToCodeRange(
                        id: promptToCode.id,
                        range: .init(start: range.start, end: cursorPosition)
                    ))
                )
                viewStore.send(
                    .promptToCodeGroup(.discardAcceptedPromptToCodeIfNotContinuous(
                        id: promptToCode.id
                    ))
                )
            }.result

            return .init(
                content: String(lines.joined(separator: "")),
                newSelection: .init(start: range.start, end: cursorPosition),
                modifications: extraInfo.modifications
            )
        }

        return nil
    }

    func presentRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try? await prepareCache(editor: editor)
        }
        return nil
    }

    @WorkspaceActor
    func prepareCache(editor: EditorContent) async throws -> UpdatedContent? {
        guard let fileURL = XcodeInspector.shared.realtimeActiveDocumentURL else { return nil }
        let (_, filespace) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        filespace.codeMetadata.uti = editor.uti
        filespace.codeMetadata.tabSize = editor.tabSize
        filespace.codeMetadata.indentSize = editor.indentSize
        filespace.codeMetadata.usesTabsForIndentation = editor.usesTabsForIndentation
        filespace.codeMetadata.guessLineEnding(from: editor.lines.first)
        return nil
    }

    func generateRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        return try await presentSuggestions(editor: editor)
    }

    func chatWithSelection(editor: EditorContent) async throws -> UpdatedContent? {
        Task { @MainActor in
            let viewStore = Service.shared.guiController.viewStore
            viewStore.send(.createChatGPTChatTabIfNeeded)
            viewStore.send(.openChatPanel(forceDetach: false))
        }
        return nil
    }

    func promptToCode(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await presentPromptToCode(
                    editor: editor,
                    extraSystemPrompt: nil,
                    prompt: nil,
                    isContinuous: false,
                    generateDescription: nil,
                    name: nil
                )
            } catch {
                presenter.presentError(error)
            }
        }
        return nil
    }

    func customCommand(id: String, editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await handleCustomCommand(id: id, editor: editor)
            } catch {
                presenter.presentError(error)
            }
        }
        return nil
    }
}

extension WindowBaseCommandHandler {
    func handleCustomCommand(id: String, editor: EditorContent) async throws {
        struct CommandNotFoundError: Error, LocalizedError {
            var errorDescription: String? { "Command not found" }
        }

        let availableCommands = UserDefaults.shared.value(for: \.customCommands)
        guard let command = availableCommands.first(where: { $0.id == id })
        else { throw CommandNotFoundError() }

        switch command.feature {
        case .chatWithSelection, .customChat:
            Task { @MainActor in
                Service.shared.guiController.viewStore
                    .send(.sendCustomCommandToActiveChat(command))
            }
        case let .promptToCode(extraSystemPrompt, prompt, continuousMode, generateDescription):
            try await presentPromptToCode(
                editor: editor,
                extraSystemPrompt: extraSystemPrompt,
                prompt: prompt,
                isContinuous: continuousMode ?? false,
                generateDescription: generateDescription,
                name: command.name
            )
        case let .singleRoundDialog(
            systemPrompt,
            overwriteSystemPrompt,
            prompt,
            receiveReplyInNotification
        ):
            try await executeSingleRoundDialog(
                systemPrompt: systemPrompt,
                overwriteSystemPrompt: overwriteSystemPrompt ?? false,
                prompt: prompt ?? "",
                receiveReplyInNotification: receiveReplyInNotification ?? false
            )
        }
    }

    @WorkspaceActor
    func presentPromptToCode(
        editor: EditorContent,
        extraSystemPrompt: String?,
        prompt: String?,
        isContinuous: Bool,
        generateDescription: Bool?,
        name: String?
    ) async throws {
        guard let fileURL = XcodeInspector.shared.realtimeActiveDocumentURL else { return }
        let (workspace, filespace) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        guard workspace.suggestionPlugin?.isSuggestionFeatureEnabled ?? false else {
            presenter.presentErrorMessage("Prompt to code is disabled for this project")
            return
        }

        let codeLanguage = languageIdentifierFromFileURL(fileURL)

        let (code, selection) = {
            guard var selection = editor.selections.last,
                  selection.start != selection.end
            else { return ("", .cursor(editor.cursorPosition)) }

            let isMultipleLine = selection.start.line != selection.end.line
            let isSpaceOnlyBeforeStartPositionOnTheSameLine = {
                guard selection.start.line >= 0, selection.start.line < editor.lines.count else {
                    return false
                }
                let line = editor.lines[selection.start.line]
                guard selection.start.character > 0, selection.start.character < line.count else {
                    return false
                }
                let substring =
                    line[line.startIndex..<line
                        .index(line.startIndex, offsetBy: selection.start.character)]
                return substring.allSatisfy { $0.isWhitespace }
            }()

            if isMultipleLine || isSpaceOnlyBeforeStartPositionOnTheSameLine {
                // when there are multiple lines start from char 0 so that it can keep the
                // indentation.
                selection.start = .init(line: selection.start.line, character: 0)
            }
            return (
                editor.selectedCode(in: selection),
                .init(
                    start: .init(line: selection.start.line, character: selection.start.character),
                    end: .init(line: selection.end.line, character: selection.end.character)
                )
            )
        }() as (String, CursorRange)

        let viewStore = Service.shared.guiController.viewStore

        let customCommandTemplateProcessor = CustomCommandTemplateProcessor()
        let newExtraSystemPrompt = extraSystemPrompt.map(customCommandTemplateProcessor.process)
        let newPrompt = prompt.map(customCommandTemplateProcessor.process)

        _ = await Task { @MainActor in
            // if there is already a prompt to code presenting, we should not present another one
            viewStore.send(.promptToCodeGroup(.activateOrCreatePromptToCode(.init(
                code: code,
                selectionRange: selection,
                language: codeLanguage,
                identSize: filespace.codeMetadata.indentSize ?? 4,
                usesTabsForIndentation: filespace.codeMetadata.usesTabsForIndentation ?? false,
                documentURL: fileURL,
                projectRootURL: workspace.projectRootURL,
                allCode: editor.content,
                allLines: editor.lines,
                isContinuous: isContinuous,
                commandName: name,
                defaultPrompt: newPrompt ?? "",
                extraSystemPrompt: newExtraSystemPrompt,
                generateDescriptionRequirement: generateDescription
            ))))
        }.result
    }

    func executeSingleRoundDialog(
        systemPrompt: String?,
        overwriteSystemPrompt: Bool,
        prompt: String,
        receiveReplyInNotification: Bool
    ) async throws {
        guard !prompt.isEmpty else { return }

        let service = ChatService()

        let result = try await service.handleSingleRoundDialogCommand(
            systemPrompt: systemPrompt,
            overwriteSystemPrompt: overwriteSystemPrompt,
            prompt: prompt
        )

        guard receiveReplyInNotification else { return }

        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert])

        if granted {
            let content = UNMutableNotificationContent()
            content.title = "Reply"
            content.body = result
            let request = UNNotificationRequest(
                identifier: "reply",
                content: content,
                trigger: nil
            )
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                presenter.presentError(error)
            }
        } else {
            presenter.presentErrorMessage("Notification permission is not granted.")
        }
    }
}


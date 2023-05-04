import ChatService
import CopilotModel
import GitHubCopilotService
import Environment
import Foundation
import LanguageServerProtocol
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
            } catch let error as ServerError {
                Logger.service.error(error)
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

    private func _presentNextSuggestion(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
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

    private func _presentPreviousSuggestion(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
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

    private func _rejectSuggestion(editor: EditorContent) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        let fileURL = try await Environment.fetchCurrentFileURL()

        if WidgetDataSource.shared.promptToCodes[fileURL]?.promptToCodeService != nil {
            WidgetDataSource.shared.removePromptToCode(for: fileURL)
            presenter.closePromptToCode(fileURL: fileURL)
            return
        }

        let (workspace, _) = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        workspace.rejectSuggestion(forFileAt: fileURL, editor: editor)
        presenter.discardSuggestion(fileURL: fileURL)
    }

    func acceptSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }

        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, filespace) = try await Workspace.fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

        let injector = SuggestionInjector()
        var lines = editor.lines
        var cursorPosition = editor.cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()

        if let service = WidgetDataSource.shared.promptToCodes[fileURL]?.promptToCodeService {
            let suggestion = CopilotCompletion(
                text: service.code,
                position: service.selectionRange.start,
                uuid: UUID().uuidString,
                range: service.selectionRange,
                displayText: service.code
            )

            injector.acceptSuggestion(
                intoContentWithoutSuggestion: &lines,
                cursorPosition: &cursorPosition,
                completion: suggestion,
                extraInfo: &extraInfo
            )

            if service.isContinuous {
                service.selectionRange = .init(
                    start: service.selectionRange.start,
                    end: cursorPosition
                )
                presenter.presentPromptToCode(fileURL: fileURL)
            } else {
                WidgetDataSource.shared.removePromptToCode(for: fileURL)
                presenter.closePromptToCode(fileURL: fileURL)
            }

            return .init(
                content: String(lines.joined(separator: "")),
                newSelection: .init(start: service.selectionRange.start, end: cursorPosition),
                modifications: extraInfo.modifications
            )
        } else if let acceptedSuggestion = workspace.acceptSuggestion(
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

    func presentRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try? await prepareCache(editor: editor)
        }
        return nil
    }

    func prepareCache(editor: EditorContent) async throws -> UpdatedContent? {
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (_, filespace) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        filespace.uti = editor.uti
        filespace.tabSize = editor.tabSize
        filespace.indentSize = editor.indentSize
        filespace.usesTabsForIndentation = editor.usesTabsForIndentation
        return nil
    }

    func generateRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        return try await presentSuggestions(editor: editor)
    }

    func chatWithSelection(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await startChatWithSelection(
                    editor: editor,
                    specifiedSystemPrompt: nil,
                    extraSystemPrompt: nil,
                    sendingMessageImmediately: nil,
                    name: nil
                )
            } catch {
                presenter.presentError(error)
            }
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
        case let .chatWithSelection(extraSystemPrompt, prompt):
            try await startChatWithSelection(
                editor: editor,
                specifiedSystemPrompt: nil,
                extraSystemPrompt: extraSystemPrompt,
                sendingMessageImmediately: prompt,
                name: command.name
            )
        case let .customChat(systemPrompt, prompt):
            try await startChat(
                specifiedSystemPrompt: systemPrompt,
                extraSystemPrompt: nil,
                sendingMessageImmediately: prompt,
                name: command.name
            )
        case let .promptToCode(extraSystemPrompt, prompt, continuousMode):
            try await presentPromptToCode(
                editor: editor,
                extraSystemPrompt: extraSystemPrompt,
                prompt: prompt,
                isContinuous: continuousMode ?? false,
                name: command.name
            )
        }
    }

    func presentPromptToCode(
        editor: EditorContent,
        extraSystemPrompt: String?,
        prompt: String?,
        isContinuous: Bool,
        name: String?
    ) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }
        let fileURL = try await Environment.fetchCurrentFileURL()
        let (workspace, _) = try await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        guard workspace.isSuggestionFeatureEnabled else {
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

        let promptToCode = await WidgetDataSource.shared.createPromptToCode(
            for: fileURL,
            projectURL: workspace.projectRootURL,
            selectedCode: code,
            allCode: editor.content,
            selectionRange: selection,
            language: codeLanguage,
            extraSystemPrompt: extraSystemPrompt,
            name: name
        )

        promptToCode.isContinuous = isContinuous
        if let prompt, !prompt.isEmpty {
            Task { try await promptToCode.modifyCode(prompt: prompt) }
        }

        presenter.presentPromptToCode(fileURL: fileURL)
    }

    private func startChatWithSelection(
        editor: EditorContent,
        specifiedSystemPrompt: String?,
        extraSystemPrompt: String?,
        sendingMessageImmediately: String?,
        name: String?
    ) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }

        let fileURL = try await Environment.fetchCurrentFileURL()
        let language = UserDefaults.shared.value(for: \.chatGPTLanguage)
        let codeLanguage = languageIdentifierFromFileURL(fileURL)

        let code = {
            guard let selection = editor.selections.last,
                  selection.start != selection.end else { return "" }
            return editor.selectedCode(in: selection)
        }()

        var systemPrompt = specifiedSystemPrompt ?? {
            if code.isEmpty {
                return """
                \(language.isEmpty ? "" : "You must always reply in \(language)")
                You are a senior programmer, you will answer my questions concisely. If you are replying with code, embed the code in a code block in markdown.
                
                You don't have any code in advance, ask me to provide it when needed.
                """
            }
            return """
            \(language.isEmpty ? "" : "You must always reply in \(language)")
            You are a senior programmer, you will answer my questions concisely about the code below, or modify it according to my requests. When you receive a modification request, reply with the modified code in a code block.
            ```\(codeLanguage.rawValue)
            \(code)
            ```
            """
        }()

        if let extraSystemPrompt {
            systemPrompt += "\n\(extraSystemPrompt)"
        }

        let chat = WidgetDataSource.shared.createChatIfNeeded(for: fileURL)

        await chat.mutateSystemPrompt(systemPrompt)

        Task {
            let customCommandPrefix = {
                if let name { return "[\(name)] " }
                return ""
            }()
            
            if specifiedSystemPrompt != nil {
                await chat.chatGPTService.mutateHistory { history in
                    history.append(.init(
                        role: .assistant,
                        content: "",
                        summary: "\(customCommandPrefix)System prompt is updated."
                    ))
                }
            } else if !code.isEmpty, let selection = editor.selections.last {
                await chat.chatGPTService.mutateHistory { history in
                    history.append(.init(
                        role: .assistant,
                        content: "",
                        summary: "\(customCommandPrefix)Chatting about selected code in `\(fileURL.lastPathComponent)` from `\(selection.start.line + 1):\(selection.start.character + 1)` to `\(selection.end.line + 1):\(selection.end.character)`.\nThe code will persist in the conversation."
                    ))
                }
            } else if !customCommandPrefix.isEmpty {
                await chat.chatGPTService.mutateHistory { history in
                    history.append(.init(
                        role: .assistant,
                        content: "",
                        summary: "\(customCommandPrefix)System prompt is updated."
                    ))
                }
            }

            if let sendingMessageImmediately, !sendingMessageImmediately.isEmpty {
                try await chat.send(content: sendingMessageImmediately)
            }
        }

        presenter.presentChatRoom(fileURL: fileURL)
    }
    
    private func startChat(
        specifiedSystemPrompt: String?,
        extraSystemPrompt: String?,
        sendingMessageImmediately: String?,
        name: String?
    ) async throws {
        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }

        let focusedElementURI = try await Environment.fetchFocusedElementURI()
        let language = UserDefaults.shared.value(for: \.chatGPTLanguage)

        var systemPrompt = specifiedSystemPrompt ?? """
        \(language.isEmpty ? "" : "You must always reply in \(language)")
        You are a senior programmer, you will answer my questions concisely. If you are replying with code, embed the code in a code block in markdown.
        
        You don't have any code in advance, ask me to provide it when needed.
        """

        if let extraSystemPrompt {
            systemPrompt += "\n\(extraSystemPrompt)"
        }

        let chat = WidgetDataSource.shared.createChatIfNeeded(for: focusedElementURI)

        await chat.mutateSystemPrompt(systemPrompt)

        Task {
            let customCommandPrefix = {
                if let name { return "[\(name)] " }
                return ""
            }()
            
            if specifiedSystemPrompt != nil {
                await chat.chatGPTService.mutateHistory { history in
                    history.append(.init(
                        role: .assistant,
                        content: "",
                        summary: "\(customCommandPrefix)System prompt is updated."
                    ))
                }
            } else if !customCommandPrefix.isEmpty {
                await chat.chatGPTService.mutateHistory { history in
                    history.append(.init(
                        role: .assistant,
                        content: "",
                        summary: "\(customCommandPrefix)System prompt is updated."
                    ))
                }
            }

            if let sendingMessageImmediately, !sendingMessageImmediately.isEmpty {
                try await chat.send(content: sendingMessageImmediately)
            }
        }

        presenter.presentChatRoom(fileURL: focusedElementURI)
    }
}

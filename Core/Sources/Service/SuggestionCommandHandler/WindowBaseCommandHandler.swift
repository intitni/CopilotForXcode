import AppKit
import ChatService
import ComposableArchitecture
import CustomCommandTemplateProcessor
import Foundation
import GitHubCopilotService
import LanguageServerProtocol
import Logger
import ModificationBasic
import OpenAIService
import SuggestionBasic
import SuggestionInjector
import SuggestionWidget
import Toast
import UserNotifications
import Workspace
import WorkspaceSuggestionService
import XcodeInspector
import XPCShared

struct WindowBaseCommandHandler: SuggestionCommandHandler {
    nonisolated init() {}

    let presenter = PresentInWindowSuggestionPresenter()
    private var toast: ToastController { ToastControllerDependencyKey.liveValue }

    func presentSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _presentSuggestions(editor: editor)
            } catch let error as ServerError {
                Logger.service.error(error)
            } catch {
                toast.toast(content: error.localizedDescription, type: .error)
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
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return }
        let (workspace, _) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)

        try Task.checkCancellation()

        try await workspace.generateSuggestions(
            forFileAt: fileURL,
            editor: editor
        )

        try Task.checkCancellation()
    }

    func presentNextSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task { await PseudoCommandHandler().presentNextSuggestion(atIndex: nil) }
        return nil
    }

    func presentPreviousSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task { await PseudoCommandHandler().presentPreviousSuggestion(atIndex: nil) }
        return nil
    }
    
    func presentNextSuggestionGroup() async throws {
        Task { await PseudoCommandHandler().presentNextSuggestionGroup() }
    }

    func presentPreviousSuggestionGroup() async throws {
        Task { await PseudoCommandHandler().presentPreviousSuggestionGroup() }
    }

    func rejectSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task { await PseudoCommandHandler().rejectSuggestionGroup(editor: editor, atIndex: nil) }
        return nil
    }

    func acceptSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        if let acceptedSuggestion = try await PseudoCommandHandler().handleAcceptSuggestionCommand(
            editor: editor
        ) {
            let injector = SuggestionInjector()
            var lines = editor.lines
            var cursorPosition = editor.cursorPosition
            var extraInfo = SuggestionInjector.ExtraInfo()

            injector.acceptSuggestion(
                intoContentWithoutSuggestion: &lines,
                cursorPosition: &cursorPosition,
                completion: acceptedSuggestion,
                extraInfo: &extraInfo
            )

            return .init(
                content: String(lines.joined(separator: "")),
                newSelection: .cursor(cursorPosition),
                modifications: extraInfo.modifications
            )
        }

        return nil
    }

    func acceptSuggestionLine(editor: EditorContent) async throws -> UpdatedContent? {
        if let acceptedSuggestion = try await PseudoCommandHandler()
            .handleAcceptSuggestionLineCommand(editor: editor)
        {
            let injector = SuggestionInjector()
            var lines = editor.lines
            var cursorPosition = editor.cursorPosition
            var extraInfo = SuggestionInjector.ExtraInfo()

            injector.acceptSuggestion(
                intoContentWithoutSuggestion: &lines,
                cursorPosition: &cursorPosition,
                completion: acceptedSuggestion,
                extraInfo: &extraInfo
            )

            return .init(
                content: String(lines.joined(separator: "")),
                newSelection: .cursor(cursorPosition),
                modifications: extraInfo.modifications
            )
        }

        return nil
    }
    
    #warning("TODO: This function is not implemented")
    func acceptSuggestionNextWord(editor: EditorContent) async throws -> UpdatedContent? {
        if let acceptedSuggestion = try await PseudoCommandHandler()
            .handleAcceptSuggestionLineCommand(editor: editor)
        {
            let injector = SuggestionInjector()
            var lines = editor.lines
            var cursorPosition = editor.cursorPosition
            var extraInfo = SuggestionInjector.ExtraInfo()

            injector.acceptSuggestion(
                intoContentWithoutSuggestion: &lines,
                cursorPosition: &cursorPosition,
                completion: acceptedSuggestion,
                extraInfo: &extraInfo
            )

            return .init(
                content: String(lines.joined(separator: "")),
                newSelection: .cursor(cursorPosition),
                modifications: extraInfo.modifications
            )
        }

        return nil
    }

    func acceptPromptToCode(editor: EditorContent) async throws -> UpdatedContent? {
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return nil }

        let injector = SuggestionInjector()
        var lines = editor.lines
        var cursorPosition = editor.cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()

        let store = await Service.shared.guiController.store

        if let promptToCode = await MainActor
            .run(body: { store.state.promptToCodeGroup.activePromptToCode })
        {
            if promptToCode.promptToCodeState.isAttachedToTarget,
               promptToCode.promptToCodeState.source.documentURL != fileURL
            {
                return nil
            }

            let suggestions = promptToCode.promptToCodeState.snippets
                .map { snippet in
                    let range = {
                        if promptToCode.promptToCodeState.isAttachedToTarget {
                            return snippet.attachedRange
                        }
                        return editor.selections.first.map {
                            CursorRange(start: $0.start, end: $0.end)
                        } ?? CursorRange(
                            start: editor.cursorPosition,
                            end: editor.cursorPosition
                        )
                    }()
                    return CodeSuggestion(
                        id: snippet.id.uuidString,
                        text: snippet.modifiedCode,
                        position: range.start,
                        range: range
                    )
                }

            injector.acceptSuggestions(
                intoContentWithoutSuggestion: &lines,
                cursorPosition: &cursorPosition,
                completions: suggestions,
                extraInfo: &extraInfo
            )

            for (id, range) in extraInfo.modificationRanges {
                _ = await MainActor.run {
                    store.send(
                        .promptToCodeGroup(.updatePromptToCodeRange(
                            id: promptToCode.id,
                            snippetId: .init(uuidString: id) ?? .init(),
                            range: range
                        ))
                    )
                }
            }

            _ = await MainActor.run {
                store.send(
                    .promptToCodeGroup(.discardAcceptedPromptToCodeIfNotContinuous(
                        id: promptToCode.id
                    ))
                )
            }

            return .init(
                content: String(lines.joined(separator: "")),
                newSelections: extraInfo.modificationRanges.values
                    .sorted(by: { $0.start.line <= $1.start.line }),
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
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return nil }
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
                toast.toast(content: error.localizedDescription, type: .error)
            }
        }
        return nil
    }

    func customCommand(id: String, editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await handleCustomCommand(id: id, editor: editor)
            } catch {
                toast.toast(content: error.localizedDescription, type: .error)
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
                Service.shared.guiController.store
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
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return }
        let (workspace, _) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        guard workspace.suggestionPlugin?.isSuggestionFeatureEnabled ?? false else {
            toast.toast(content: "Prompt to code is disabled for this project", type: .error)
            return
        }

        let codeLanguage = languageIdentifierFromFileURL(fileURL)

        let selections: [CursorRange] = {
            var all = [CursorRange]()

            // join the ranges if they overlaps in line

            for selection in editor.selections {
                let range = CursorRange(start: selection.start, end: selection.end)

                func intersect(_ lhs: CursorRange, _ rhs: CursorRange) -> Bool {
                    lhs.start.line <= rhs.end.line && lhs.end.line >= rhs.start.line
                }

                if let last = all.last, intersect(last, range) {
                    all[all.count - 1] = CursorRange(
                        start: .init(
                            line: min(last.start.line, range.start.line),
                            character: min(last.start.character, range.start.character)
                        ),
                        end: .init(
                            line: max(last.end.line, range.end.line),
                            character: max(last.end.character, range.end.character)
                        )
                    )
                } else {
                    all.append(range)
                }
            }

            return all
        }()

        let snippets = selections.map { selection in
            guard selection.start != selection.end else {
                return ModificationSnippet(
                    startLineIndex: selection.start.line,
                    originalCode: "",
                    modifiedCode: "",
                    description: "",
                    error: "",
                    attachedRange: selection
                )
            }
            var selection = selection
            let isMultipleLine = selection.start.line != selection.end.line
            let isSpaceOnlyBeforeStartPositionOnTheSameLine = {
                guard selection.start.line >= 0, selection.start.line < editor.lines.count else {
                    return false
                }
                let line = editor.lines[selection.start.line]
                guard selection.start.character > 0,
                      selection.start.character < line.utf16.count
                else { return false }
                let substring = line[line.utf16.startIndex..<(line.index(
                    line.utf16.startIndex,
                    offsetBy: selection.start.character,
                    limitedBy: line.utf16.endIndex
                ) ?? line.utf16.endIndex)]
                return substring.allSatisfy { $0.isWhitespace }
            }()

            if isMultipleLine || isSpaceOnlyBeforeStartPositionOnTheSameLine {
                // when there are multiple lines start from char 0 so that it can keep the
                // indentation.
                selection.start = .init(line: selection.start.line, character: 0)
            }
            let selectedCode = editor.selectedCode(in: .init(
                start: selection.start,
                end: selection.end
            ))
            return ModificationSnippet(
                startLineIndex: selection.start.line,
                originalCode: selectedCode,
                modifiedCode: selectedCode,
                description: "",
                error: "",
                attachedRange: .init(start: selection.start, end: selection.end)
            )
        }

        let store = await Service.shared.guiController.store

        let customCommandTemplateProcessor = CustomCommandTemplateProcessor()

        let newExtraSystemPrompt: String? = if let extraSystemPrompt {
            await customCommandTemplateProcessor.process(extraSystemPrompt)
        } else {
            nil
        }

        let newPrompt: String? = if let prompt {
            await customCommandTemplateProcessor.process(prompt)
        } else {
            nil
        }

        _ = await MainActor.run {
            store.send(.promptToCodeGroup(.activateOrCreatePromptToCode(.init(
                promptToCodeState: Shared(.init(
                    source: .init(
                        language: codeLanguage,
                        documentURL: fileURL,
                        projectRootURL: workspace.projectRootURL,
                        content: editor.content,
                        lines: editor.lines
                    ),
                    snippets: IdentifiedArray(uniqueElements: snippets),
                    extraSystemPrompt: newExtraSystemPrompt ?? "",
                    isAttachedToTarget: true
                )),
                instruction: newPrompt,
                commandName: name,
                isContinuous: isContinuous
            ))))
        }
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
                toast.toast(content: error.localizedDescription, type: .error)
            }
        } else {
            toast.toast(content: "Notification permission is not granted.", type: .error)
        }
    }
}


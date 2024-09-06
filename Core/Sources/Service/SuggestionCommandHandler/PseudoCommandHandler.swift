import ActiveApplicationMonitor
import AppKit
import CodeiumService
import CommandHandler
import enum CopilotForXcodeKit.SuggestionServiceError
import Dependencies
import Logger
import PlusFeatureFlag
import Preferences
import SuggestionBasic
import SuggestionInjector
import Toast
import Workspace
import WorkspaceSuggestionService
import XcodeInspector
import XPCShared

#if canImport(BrowserChatTab)
import BrowserChatTab
#endif

/// It's used to run some commands without really triggering the menu bar item.
///
/// For example, we can use it to generate real-time suggestions without Apple Scripts.
struct PseudoCommandHandler: CommandHandler {
    static var lastTimeCommandFailedToTriggerWithAccessibilityAPI = Date(timeIntervalSince1970: 0)
    private var toast: ToastController { ToastControllerDependencyKey.liveValue }

    func presentPreviousSuggestion() async {
        let handler = WindowBaseCommandHandler()
        _ = try? await handler.presentPreviousSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            cursorOffset: -1,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }

    func presentNextSuggestion() async {
        let handler = WindowBaseCommandHandler()
        _ = try? await handler.presentNextSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            cursorOffset: -1,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }

    @WorkspaceActor
    func generateRealtimeSuggestions(sourceEditor: SourceEditor?) async {
        guard let filespace = await getFilespace(),
              let (workspace, _) = try? await Service.shared.workspacePool
              .fetchOrCreateWorkspaceAndFilespace(fileURL: filespace.fileURL) else { return }

        if Task.isCancelled { return }

        // Can't use handler if content is not available.
        guard let editor = await getEditorContent(sourceEditor: sourceEditor)
        else { return }

        let fileURL = filespace.fileURL
        let presenter = PresentInWindowSuggestionPresenter()

        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }

        if filespace.presentingSuggestion != nil {
            // Check if the current suggestion is still valid.
            if filespace.validateSuggestions(
                lines: editor.lines,
                cursorPosition: editor.cursorPosition
            ) {
                return
            } else {
                presenter.discardSuggestion(fileURL: filespace.fileURL)
            }
        }

        let snapshot = FilespaceSuggestionSnapshot(
            lines: editor.lines,
            cursorPosition: editor.cursorPosition
        )

        guard filespace.suggestionSourceSnapshot != snapshot else { return }

        do {
            try await workspace.generateSuggestions(
                forFileAt: fileURL,
                editor: editor
            )
            if let sourceEditor {
                let editorContent = sourceEditor.getContent()
                _ = filespace.validateSuggestions(
                    lines: editorContent.lines,
                    cursorPosition: editorContent.cursorPosition
                )
            }
            if filespace.presentingSuggestion != nil {
                presenter.presentSuggestion(fileURL: fileURL)
            } else {
                presenter.discardSuggestion(fileURL: fileURL)
            }
        } catch let error as SuggestionServiceError {
            switch error {
            case let .notice(error):
                presenter.presentErrorMessage(error.localizedDescription)
            case .silent:
                Logger.service.error(error.localizedDescription)
                return
            }
        } catch {
            Logger.service.error(error.localizedDescription)
            return
        }
    }

    @WorkspaceActor
    func invalidateRealtimeSuggestionsIfNeeded(fileURL: URL, sourceEditor: SourceEditor) async {
        guard let (_, filespace) = try? await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL) else { return }

        if filespace.presentingSuggestion == nil {
            return // skip if there's no suggestion presented.
        }

        let content = sourceEditor.getContent()
        if !filespace.validateSuggestions(
            lines: content.lines,
            cursorPosition: content.cursorPosition
        ) {
            PresentInWindowSuggestionPresenter().discardSuggestion(fileURL: fileURL)
        }
    }

    func rejectSuggestions() async {
        let handler = WindowBaseCommandHandler()
        _ = try? await handler.rejectSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            cursorOffset: -1,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }

    func handleCustomCommand(_ command: CustomCommand) async {
        guard let editor = await {
            if let it = await getEditorContent(sourceEditor: nil) {
                return it
            }
            switch command.feature {
            // editor content is not required.
            case .customChat, .chatWithSelection, .singleRoundDialog:
                return .init(
                    content: "",
                    lines: [],
                    uti: "",
                    cursorPosition: .outOfScope,
                    cursorOffset: -1,
                    selections: [],
                    tabSize: 0,
                    indentSize: 0,
                    usesTabsForIndentation: false
                )
            // editor content is required.
            case .promptToCode:
                return nil
            }
        }() else {
            do {
                try await XcodeInspector.shared.safe.latestActiveXcode?
                    .triggerCopilotCommand(name: command.name)
            } catch {
                let presenter = PresentInWindowSuggestionPresenter()
                presenter.presentError(error)
            }
            return
        }

        let handler = WindowBaseCommandHandler()
        do {
            try await handler.handleCustomCommand(id: command.id, editor: editor)
        } catch {
            let presenter = PresentInWindowSuggestionPresenter()
            presenter.presentError(error)
        }
    }

    func acceptPromptToCode() async {
        do {
            if UserDefaults.shared.value(for: \.alwaysAcceptSuggestionWithAccessibilityAPI) {
                throw CancellationError()
            }
            do {
                try await XcodeInspector.shared.safe.latestActiveXcode?
                    .triggerCopilotCommand(name: "Accept Modification")
            } catch {
                do {
                    try await XcodeInspector.shared.safe.latestActiveXcode?
                        .triggerCopilotCommand(name: "Accept Prompt to Code")
                } catch {
                    let last = Self.lastTimeCommandFailedToTriggerWithAccessibilityAPI
                    let now = Date()
                    if now.timeIntervalSince(last) > 60 * 60 {
                        Self.lastTimeCommandFailedToTriggerWithAccessibilityAPI = now
                        toast.toast(content: """
                    The app is using a fallback solution to accept suggestions. \
                    For better experience, please restart Xcode to re-activate the Copilot \
                    menu item.
                    """, type: .warning)
                    }
                    
                    throw error
                }
            }
        } catch {
            guard let xcode = ActiveApplicationMonitor.shared.activeXcode
                ?? ActiveApplicationMonitor.shared.latestXcode else { return }
            let application = AXUIElementCreateApplication(xcode.processIdentifier)
            guard let focusElement = application.focusedElement,
                  focusElement.description == "Source Editor"
            else { return }
            guard let (
                content,
                lines,
                _,
                cursorPosition,
                cursorOffset
            ) = await getFileContent(sourceEditor: nil)
            else {
                PresentInWindowSuggestionPresenter()
                    .presentErrorMessage("Unable to get file content.")
                return
            }
            let handler = WindowBaseCommandHandler()
            do {
                guard let result = try await handler.acceptPromptToCode(editor: .init(
                    content: content,
                    lines: lines,
                    uti: "",
                    cursorPosition: cursorPosition,
                    cursorOffset: cursorOffset,
                    selections: [],
                    tabSize: 0,
                    indentSize: 0,
                    usesTabsForIndentation: false
                )) else { return }

                try injectUpdatedCodeWithAccessibilityAPI(result, focusElement: focusElement)
            } catch {
                PresentInWindowSuggestionPresenter().presentError(error)
            }
        }
    }

    func acceptSuggestion() async {
        do {
            if UserDefaults.shared.value(for: \.alwaysAcceptSuggestionWithAccessibilityAPI) {
                throw CancellationError()
            }
            do {
                try await XcodeInspector.shared.safe.latestActiveXcode?
                    .triggerCopilotCommand(name: "Accept Suggestion")
            } catch {
                let last = Self.lastTimeCommandFailedToTriggerWithAccessibilityAPI
                let now = Date()
                if now.timeIntervalSince(last) > 60 * 60 {
                    Self.lastTimeCommandFailedToTriggerWithAccessibilityAPI = now
                    toast.toast(content: """
                    The app is using a fallback solution to accept suggestions. \
                    For better experience, please restart Xcode to re-activate the Copilot \
                    menu item.
                    """, type: .warning)
                }

                throw error
            }
        } catch {
            guard let xcode = ActiveApplicationMonitor.shared.activeXcode
                ?? ActiveApplicationMonitor.shared.latestXcode else { return }
            let application = AXUIElementCreateApplication(xcode.processIdentifier)
            guard let focusElement = application.focusedElement,
                  focusElement.description == "Source Editor"
            else { return }
            guard let (
                content,
                lines,
                _,
                cursorPosition,
                cursorOffset
            ) = await getFileContent(sourceEditor: nil)
            else {
                PresentInWindowSuggestionPresenter()
                    .presentErrorMessage("Unable to get file content.")
                return
            }
            let handler = WindowBaseCommandHandler()
            do {
                guard let result = try await handler.acceptSuggestion(editor: .init(
                    content: content,
                    lines: lines,
                    uti: "",
                    cursorPosition: cursorPosition,
                    cursorOffset: cursorOffset,
                    selections: [],
                    tabSize: 0,
                    indentSize: 0,
                    usesTabsForIndentation: false
                )) else { return }

                try injectUpdatedCodeWithAccessibilityAPI(result, focusElement: focusElement)
            } catch {
                PresentInWindowSuggestionPresenter().presentError(error)
            }
        }
    }

    func dismissSuggestion() async {
        guard let documentURL = await XcodeInspector.shared.safe.activeDocumentURL else { return }
        PresentInWindowSuggestionPresenter().discardSuggestion(fileURL: documentURL)
        guard let (_, filespace) = try? await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: documentURL) else { return }
        await filespace.reset()
    }

    func openChat(forceDetach: Bool, activateThisApp: Bool = true) {
        switch UserDefaults.shared.value(for: \.openChatMode) {
        case .chatPanel:
            Task { @MainActor in
                let store = Service.shared.guiController.store
                await store.send(.createAndSwitchToChatGPTChatTabIfNeeded).finish()
                store.send(.openChatPanel(
                    forceDetach: forceDetach,
                    activateThisApp: activateThisApp
                ))
            }
        case .browser:
            let urlString = UserDefaults.shared.value(for: \.openChatInBrowserURL)
            let openInApp = {
                if !UserDefaults.shared.value(for: \.openChatInBrowserInInAppBrowser) {
                    return false
                }
                return isFeatureAvailable(\.browserTab)
            }()
            guard let url = URL(string: urlString) else {
                let alert = NSAlert()
                alert.messageText = "Invalid URL"
                alert.informativeText = "The URL provided is not valid."
                alert.alertStyle = .warning
                alert.runModal()
                return
            }

            if openInApp {
                #if canImport(BrowserChatTab)
                Task { @MainActor in
                    let store = Service.shared.guiController.store
                    await store.send(.createAndSwitchToChatTabIfNeededMatching(
                        check: {
                            func match(_ tabURL: URL?) -> Bool {
                                guard let tabURL else { return false }
                                return tabURL == url
                                    || tabURL.absoluteString.hasPrefix(url.absoluteString)
                            }

                            guard let tab = $0 as? BrowserChatTab,
                                  match(tab.url) else { return false }
                            return true
                        },
                        kind: .init(BrowserChatTab.urlChatBuilder(url: url))
                    )).finish()
                    store.send(.openChatPanel(
                        forceDetach: forceDetach,
                        activateThisApp: activateThisApp
                    ))
                }
                #endif
            } else {
                Task {
                    @Dependency(\.openURL) var openURL
                    await openURL(url)
                }
            }
        case .codeiumChat:
            Task { @MainActor in
                let store = Service.shared.guiController.store
                await store.send(
                    .createAndSwitchToChatTabIfNeededMatching(
                        check: { $0 is CodeiumChatTab },
                        kind: .init(CodeiumChatTab.defaultChatBuilder())
                    )
                ).finish()
                store.send(.openChatPanel(
                    forceDetach: forceDetach,
                    activateThisApp: activateThisApp
                ))
            }
        }
    }

    @MainActor
    func sendChatMessage(_ message: String) async {
        let store = Service.shared.guiController.store
        await store.send(.sendCustomCommandToActiveChat(CustomCommand(
            commandId: "",
            name: "",
            feature: .chatWithSelection(
                extraSystemPrompt: nil,
                prompt: message,
                useExtraSystemPrompt: nil
            )
        ))).finish()
    }

    @WorkspaceActor
    func presentSuggestions(_ suggestions: [SuggestionBasic.CodeSuggestion]) async {
        guard let filespace = await getFilespace() else { return }
        filespace.setSuggestions(suggestions)
        PresentInWindowSuggestionPresenter().presentSuggestion(fileURL: filespace.fileURL)
    }

    func toast(_ message: String, as type: ToastType) {
        Task { @MainActor in
            let store = Service.shared.guiController.store
            store.send(.suggestionWidget(.toastPanel(.toast(.toast(message, type, nil)))))
        }
    }
}

extension PseudoCommandHandler {
    /// When Xcode commands are not available, we can fallback to directly
    /// set the value of the editor with Accessibility API.
    func injectUpdatedCodeWithAccessibilityAPI(
        _ result: UpdatedContent,
        focusElement: AXUIElement
    ) throws {
        let oldPosition = focusElement.selectedTextRange
        let oldScrollPosition = focusElement.parent?.verticalScrollBar?.doubleValue

        let error = AXUIElementSetAttributeValue(
            focusElement,
            kAXValueAttribute as CFString,
            result.content as CFTypeRef
        )

        if error != AXError.success {
            PresentInWindowSuggestionPresenter()
                .presentErrorMessage("Fail to set editor content.")
        }

        // recover selection range

        if let selection = result.newSelections.first {
            var range = SourceEditor.convertCursorRangeToRange(selection, in: result.content)
            if let value = AXValueCreate(.cfRange, &range) {
                AXUIElementSetAttributeValue(
                    focusElement,
                    kAXSelectedTextRangeAttribute as CFString,
                    value
                )
            }
        } else if let oldPosition {
            var range = CFRange(
                location: oldPosition.lowerBound,
                length: 0
            )
            if let value = AXValueCreate(.cfRange, &range) {
                AXUIElementSetAttributeValue(
                    focusElement,
                    kAXSelectedTextRangeAttribute as CFString,
                    value
                )
            }
        }

        // recover scroll position

        if let oldScrollPosition,
           let scrollBar = focusElement.parent?.verticalScrollBar
        {
            AXUIElementSetAttributeValue(
                scrollBar,
                kAXValueAttribute as CFString,
                oldScrollPosition as CFTypeRef
            )
        }
    }

    func getFileContent(sourceEditor: AXUIElement?) async
        -> (
            content: String,
            lines: [String],
            selections: [CursorRange],
            cursorPosition: CursorPosition,
            cursorOffset: Int
        )?
    {
        guard let xcode = ActiveApplicationMonitor.shared.activeXcode
            ?? ActiveApplicationMonitor.shared.latestXcode else { return nil }
        let application = AXUIElementCreateApplication(xcode.processIdentifier)
        guard let focusElement = sourceEditor ?? application.focusedElement,
              focusElement.description == "Source Editor"
        else { return nil }
        guard let selectionRange = focusElement.selectedTextRange else { return nil }
        let content = focusElement.value
        let split = content.breakLines(appendLineBreakToLastLine: false)
        let range = SourceEditor.convertRangeToCursorRange(selectionRange, in: content)
        return (content, split, [range], range.start, selectionRange.lowerBound)
    }

    func getFileURL() async -> URL? {
        await XcodeInspector.shared.safe.realtimeActiveDocumentURL
    }

    @WorkspaceActor
    func getFilespace() async -> Filespace? {
        guard
            let fileURL = await getFileURL(),
            let (_, filespace) = try? await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        else { return nil }
        return filespace
    }

    @WorkspaceActor
    func getEditorContent(sourceEditor: SourceEditor?) async -> EditorContent? {
        guard let filespace = await getFilespace(),
              let sourceEditor = await {
                  if let sourceEditor { sourceEditor }
                  else { await XcodeInspector.shared.safe.focusedEditor }
              }()
        else { return nil }
        if Task.isCancelled { return nil }
        let content = sourceEditor.getContent()
        let uti = filespace.codeMetadata.uti ?? ""
        let tabSize = filespace.codeMetadata.tabSize ?? 4
        let indentSize = filespace.codeMetadata.indentSize ?? 4
        let usesTabsForIndentation = filespace.codeMetadata.usesTabsForIndentation ?? false
        return .init(
            content: content.content,
            lines: content.lines,
            uti: uti,
            cursorPosition: content.cursorPosition,
            cursorOffset: content.cursorOffset,
            selections: content.selections.map {
                .init(start: $0.start, end: $0.end)
            },
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation
        )
    }
}


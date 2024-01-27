import ChatGPTChatTab
import ChatService
import ChatTab
import Foundation
import PromptToCodeService
import SuggestionModel
import SuggestionWidget
import XcodeInspector

#if canImport(ProChatTabs)
import ProChatTabs

enum ChatTabFactory {
    static func chatTabBuilderCollection() -> [ChatTabBuilderCollection] {
        func folderIfNeeded(
            _ builders: [any ChatTabBuilder],
            title: String
        ) -> ChatTabBuilderCollection? {
            if builders.count > 1 {
                return .folder(title: title, kinds: builders.map(ChatTabKind.init))
            }
            if let first = builders.first { return .kind(ChatTabKind(first)) }
            return nil
        }

        let collection = [
            folderIfNeeded(ChatGPTChatTab.chatBuilders(), title: ChatGPTChatTab.name),
            folderIfNeeded(
                BrowserChatTab.chatBuilders(
                    externalDependency: externalDependenciesForBrowserChatTab()
                ),
                title: BrowserChatTab.name
            ),
            folderIfNeeded(TerminalChatTab.chatBuilders(), title: TerminalChatTab.name),
        ].compactMap { $0 }

        return collection
    }

    static func externalDependenciesForBrowserChatTab() -> BrowserChatTab.ExternalDependency {
        .init(
            getEditorContent: {
                guard let editor = XcodeInspector.shared.focusedEditor else {
                    return .init(selectedText: "", language: "", fileContent: "")
                }
                let content = editor.getContent()
                return .init(
                    selectedText: content.selectedContent,
                    language: (
                        XcodeInspector.shared.activeDocumentURL
                            .map(languageIdentifierFromFileURL) ?? .plaintext
                    ).rawValue,
                    fileContent: content.content
                )
            },
            handleCustomCommand: { command, prompt in
                switch command.feature {
                case let .chatWithSelection(extraSystemPrompt, _, useExtraSystemPrompt):
                    let service = ChatService()
                    return try await service.processMessage(
                        systemPrompt: nil,
                        extraSystemPrompt: (useExtraSystemPrompt ?? false) ? extraSystemPrompt :
                            nil,
                        prompt: prompt
                    )
                case let .customChat(systemPrompt, _):
                    let service = ChatService()
                    return try await service.processMessage(
                        systemPrompt: systemPrompt,
                        extraSystemPrompt: nil,
                        prompt: prompt
                    )
                case let .singleRoundDialog(
                    systemPrompt,
                    overwriteSystemPrompt,
                    _,
                    _
                ):
                    let service = ChatService()
                    return try await service.handleSingleRoundDialogCommand(
                        systemPrompt: systemPrompt,
                        overwriteSystemPrompt: overwriteSystemPrompt ?? false,
                        prompt: prompt
                    )
                case let .promptToCode(extraSystemPrompt, instruction, _, _):
                    let service = OpenAIPromptToCodeService()

                    let result = try await service.modifyCode(
                        code: prompt,
                        requirement: instruction ?? "Modify content.",
                        source: .init(
                            language: .plaintext,
                            documentURL: .init(fileURLWithPath: "/"),
                            projectRootURL: .init(fileURLWithPath: "/"),
                            content: prompt,
                            lines: prompt.breakLines(),
                            range: .outOfScope
                        ),
                        isDetached: true,
                        extraSystemPrompt: extraSystemPrompt,
                        generateDescriptionRequirement: false
                    )
                    var code = ""
                    for try await (newCode, _) in result {
                        code = newCode
                    }
                    return code
                }
            }
        )
    }
}

#else

enum ChatTabFactory {
    static func chatTabBuilderCollection() -> [ChatTabBuilderCollection] {
        func folderIfNeeded(
            _ builders: [any ChatTabBuilder],
            title: String
        ) -> ChatTabBuilderCollection? {
            if builders.count > 1 {
                return .folder(title: title, kinds: builders.map(ChatTabKind.init))
            }
            if let first = builders.first { return .kind(ChatTabKind(first)) }
            return nil
        }

        return [
            folderIfNeeded(ChatGPTChatTab.chatBuilders(), title: ChatGPTChatTab.name),
        ].compactMap { $0 }
    }
}

#endif


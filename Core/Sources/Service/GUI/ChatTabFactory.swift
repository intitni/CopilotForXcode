import BuiltinExtension
import ChatGPTChatTab
import ChatService
import ChatTab
import Foundation
import PromptToCodeService
import SuggestionBasic
import SuggestionWidget
import XcodeInspector

enum ChatTabFactory {
    static func chatTabBuilderCollection() -> [ChatTabBuilderCollection] {
        let chatGPTChatTab = folderIfNeeded(
            ChatGPTChatTab.chatBuilders(),
            title: ChatGPTChatTab.name
        )
        
        let (defaultChatTab, othersChatTabs) = chatTabsFromExtensions()
        
        if let defaultChatTab {
            return [defaultChatTab] + othersChatTabs + [chatGPTChatTab].compactMap(\.self)
        } else {
            return [chatGPTChatTab].compactMap(\.self) + othersChatTabs
        }
    }

    private static func folderIfNeeded(
        _ builders: [any ChatTabBuilder],
        title: String
    ) -> ChatTabBuilderCollection? {
        if builders.count > 1 {
            return .folder(title: title, kinds: builders.map(ChatTabKind.init))
        }
        if let first = builders.first { return .kind(ChatTabKind(first)) }
        return nil
    }

    static func chatTabsFromExtensions()
        -> (default: ChatTabBuilderCollection?, others: [ChatTabBuilderCollection])
    {
        let extensions = BuiltinExtensionManager.shared.extensions
        let chatTabTypes = extensions.flatMap(\.chatTabTypes)
        var defaultChatTab: ChatTabBuilderCollection?
        var otherChatTabs = [ChatTabBuilderCollection]()
        for chatTabType in chatTabTypes {
            if chatTabType.isDefaultChatTabReplacement {
                defaultChatTab = folderIfNeeded(chatTabType.chatBuilders(), title: chatTabType.name)
            } else if let tab = folderIfNeeded(
                chatTabType.chatBuilders(),
                title: chatTabType.name
            ) {
                otherChatTabs.append(tab)
            }
        }
        return (defaultChatTab, otherChatTabs)
    }
}

// #if canImport(ProChatTabs)
// let lazyLoadDependency: () = {
//    BrowserChatTab.externalDependency = .init(
//        handleCustomCommand: { command, prompt in
//           switch command.feature {
//           case let .chatWithSelection(extraSystemPrompt, _, useExtraSystemPrompt):
//               let service = ChatService()
//               return try await service.processMessage(
//                   systemPrompt: nil,
//                   extraSystemPrompt: (useExtraSystemPrompt ?? false) ? extraSystemPrompt :
//                       nil,
//                   prompt: prompt
//               )
//           case let .customChat(systemPrompt, _):
//               let service = ChatService()
//               return try await service.processMessage(
//                   systemPrompt: systemPrompt,
//                   extraSystemPrompt: nil,
//                   prompt: prompt
//               )
//           case let .singleRoundDialog(
//               systemPrompt,
//               overwriteSystemPrompt,
//               _,
//               _
//           ):
//               let service = ChatService()
//               return try await service.handleSingleRoundDialogCommand(
//                   systemPrompt: systemPrompt,
//                   overwriteSystemPrompt: overwriteSystemPrompt ?? false,
//                   prompt: prompt
//               )
//           case let .promptToCode(extraSystemPrompt, instruction, _, _):
//               let service = OpenAIPromptToCodeService()
//
//               let result = try await service.modifyCode(
//                   code: prompt,
//                   requirement: instruction ?? "Modify content.",
//                   source: .init(
//                       language: .plaintext,
//                       documentURL: .init(fileURLWithPath: "/"),
//                       projectRootURL: .init(fileURLWithPath: "/"),
//                       content: prompt,
//                       lines: prompt.breakLines(),
//                       range: .outOfScope
//                   ),
//                   isDetached: true,
//                   extraSystemPrompt: extraSystemPrompt,
//                   generateDescriptionRequirement: false
//               )
//               var code = ""
//               for try await (newCode, _) in result {
//                   code = newCode
//               }
//               return code
//           }
//       }
//    )
// }()
// #endif


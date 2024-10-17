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

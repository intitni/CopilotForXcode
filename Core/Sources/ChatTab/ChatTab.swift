import Foundation
import SwiftUI

open class BaseChatTab: Equatable {
    public let id: UUID
    
    public static func == (lhs: BaseChatTab, rhs: BaseChatTab) -> Bool {
        lhs.id == rhs.id
    }
    
    init(id: UUID) {
        self.id = id
    }
    
    @ViewBuilder
    public var body: some View {
        if let tab = self as? ChatTabType {
            AnyView(tab.buildView()).id(id)
        } else {
            EmptyView()
        }
    }
}

public protocol ChatTabType {
    @ViewBuilder
    func buildView() -> any View
}

public typealias ChatTab = BaseChatTab & ChatTabType

public class ChatGPTChatTab: ChatTab {
    public var provider: ChatProvider
    
    public func buildView() -> any View {
        ChatPanel(chat: provider)
    }

    public init(provider: ChatProvider) {
        self.provider = provider
        super.init(id: provider.id)
    }
}

public class EmptyChatTab: ChatTab {
    public func buildView() -> any View {
        EmptyView()
    }
}


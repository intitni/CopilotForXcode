import Foundation
import SwiftUI

public protocol ChatTab {
    associatedtype Body: View
    var id: UUID { get }
    @ViewBuilder @MainActor var body: Body { get }
}

public class ChatGPTChatTab: ChatTab {
    public var provider: ChatProvider
    public var id: UUID { provider.id }
    public var body: some View {
        ChatPanel(chat: provider)
    }
    
    public init(provider: ChatProvider) {
        self.provider = provider
    }
}

public class EmptyChatTab: ChatTab {
    public var id: UUID { .init() }
    
    public var body: some View {
        EmptyView()
    }
}

import Foundation
import SwiftUI

public final class ChatProvider: ObservableObject {
    @Published public var history: [ChatMessage] = []
    @Published public var isReceivingMessage = false
    public var onMessageSend: (String) -> Void
    public var onStop: () -> Void
    public var onClear: () -> Void
    public var onClose: () -> Void
    public var onSwitchContext: () -> Void

    public init(
        history: [ChatMessage] = [],
        isReceivingMessage: Bool = false,
        onMessageSend: @escaping (String) -> Void = { _ in },
        onStop: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {},
        onSwitchContext: @escaping () -> Void = {}
    ) {
        self.history = history
        self.isReceivingMessage = isReceivingMessage
        self.onMessageSend = onMessageSend
        self.onStop = onStop
        self.onClear = onClear
        self.onClose = onClose
        self.onSwitchContext = onSwitchContext
    }

    public func send(_ message: String) { onMessageSend(message) }
    public func stop() { onStop() }
    public func clear() { onClear() }
    public func close() { onClose() }
    public func switchContext() { onSwitchContext() }
}

public struct ChatMessage: Equatable {
    public var id: String
    public var isUser: Bool
    public var text: String

    public init(id: String, isUser: Bool, text: String) {
        self.id = id
        self.isUser = isUser
        self.text = text
    }
}

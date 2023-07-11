import Foundation
import OpenAIService
import Preferences
import SwiftUI

public final class ChatProvider: ObservableObject {
    public typealias MessageID = String
    public let id = UUID()
    @Published public var history: [ChatMessage] = []
    @Published public var isReceivingMessage = false
    public var pluginIdentifiers: [String] = []
    public var systemPrompt = ""
    public var title: String {
        let defaultTitle = "Chat"
        guard let lastMessageText = history
            .filter({ $0.role == .assistant || $0.role == .user })
            .last?
            .text else { return defaultTitle }
        if lastMessageText.isEmpty { return defaultTitle }
        return lastMessageText
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var extraSystemPrompt = ""
    public var onMessageSend: (String) -> Void
    public var onStop: () -> Void
    public var onClear: () -> Void
    public var onDeleteMessage: (MessageID) -> Void
    public var onResendMessage: (MessageID) -> Void
    public var onResetPrompt: () -> Void
    public var onRunCustomCommand: (CustomCommand) -> Void = { _ in }
    public var onSetAsExtraPrompt: (MessageID) -> Void

    public init(
        history: [ChatMessage] = [],
        isReceivingMessage: Bool = false,
        pluginIdentifiers: [String] = [],
        onMessageSend: @escaping (String) -> Void = { _ in },
        onStop: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {},
        onDeleteMessage: @escaping (MessageID) -> Void = { _ in },
        onResendMessage: @escaping (MessageID) -> Void = { _ in },
        onResetPrompt: @escaping () -> Void = {},
        onRunCustomCommand: @escaping (CustomCommand) -> Void = { _ in },
        onSetAsExtraPrompt: @escaping (MessageID) -> Void = { _ in }
    ) {
        self.history = history
        self.isReceivingMessage = isReceivingMessage
        self.pluginIdentifiers = pluginIdentifiers
        self.onMessageSend = onMessageSend
        self.onStop = onStop
        self.onClear = onClear
        self.onDeleteMessage = onDeleteMessage
        self.onResendMessage = onResendMessage
        self.onResetPrompt = onResetPrompt
        self.onRunCustomCommand = onRunCustomCommand
        self.onSetAsExtraPrompt = onSetAsExtraPrompt
    }

    public func send(_ message: String) { onMessageSend(message) }
    public func stop() { onStop() }
    public func clear() { onClear() }
    public func deleteMessage(id: MessageID) { onDeleteMessage(id) }
    public func resendMessage(id: MessageID) { onResendMessage(id) }
    public func resetPrompt() { onResetPrompt() }
    public func triggerCustomCommand(_ command: CustomCommand) {
        onRunCustomCommand(command)
    }

    public func setAsExtraPrompt(id: MessageID) { onSetAsExtraPrompt(id) }
}

public struct ChatMessage: Equatable {
    public enum Role {
        case user
        case assistant
        case function
        case ignored
    }

    public var id: String
    public var role: Role
    public var text: String

    public init(id: String, role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}


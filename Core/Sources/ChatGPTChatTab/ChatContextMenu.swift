import AppKit
import SharedUIComponents
import SwiftUI

struct ChatTabItemView: View {
    @ObservedObject var chat: ChatProvider
    
    var body: some View {
        Text(chat.title)
    }
}

struct ChatContextMenu: View {
    @ObservedObject var chat: ChatProvider
    @AppStorage(\.customCommands) var customCommands

    var body: some View {
        currentSystemPrompt
        currentExtraSystemPrompt
        resetPrompt

        Divider()

        customCommandMenu
    }

    @ViewBuilder
    var currentSystemPrompt: some View {
        Text("System Prompt:")
        Text({
            var text = chat.systemPrompt
            if text.isEmpty { text = "N/A" }
            if text.count > 30 { text = String(text.prefix(30)) + "..." }
            return text
        }() as String)
    }

    @ViewBuilder
    var currentExtraSystemPrompt: some View {
        Text("Extra Prompt:")
        Text({
            var text = chat.extraSystemPrompt
            if text.isEmpty { text = "N/A" }
            if text.count > 30 { text = String(text.prefix(30)) + "..." }
            return text
        }() as String)
    }

    var resetPrompt: some View {
        Button("Reset System Prompt") {
            chat.resetPrompt()
        }
    }

    var customCommandMenu: some View {
        Menu("Custom Commands") {
            ForEach(
                customCommands.filter {
                    switch $0.feature {
                    case .chatWithSelection, .customChat: return true
                    case .promptToCode: return false
                    case .singleRoundDialog: return false
                    }
                },
                id: \.name
            ) { command in
                Button(action: {
                    chat.triggerCustomCommand(command)
                }) {
                    Text(command.name)
                }
            }
        }
    }
}

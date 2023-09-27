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
    @AppStorage(\.chatModels) var chatModels
    @AppStorage(\.defaultChatFeatureChatModelId) var defaultChatModelId
    @AppStorage(\.chatGPTTemperature) var defaultTemperature

    var body: some View {
        currentSystemPrompt
        currentExtraSystemPrompt
        resetPrompt

        Divider()

        chatModel
        temperature

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

    @ViewBuilder
    var chatModel: some View {
        Menu("Chat Model") {
            Button(action: {
                chat.chatModelId = nil
            }) {
                HStack {
                    if let defaultModel = chatModels.first(where: { $0.id == defaultChatModelId }) {
                        Text("Default (\(defaultModel.name))")
                        if chat.chatModelId == nil {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text("No Model Available")
                    }
                }
            }

            if let id = chat.chatModelId,
               !chatModels.map(\.id).contains(id)
            {
                Button(action: {
                    chat.chatModelId = nil
                    chat.objectWillChange.send()
                }) {
                    HStack {
                        Text("Default (Selected Model Not Found)")
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()

            ForEach(chatModels, id: \.id) { model in
                Button(action: {
                    chat.chatModelId = model.id
                    chat.objectWillChange.send()
                }) {
                    HStack {
                        Text(model.name)
                        if model.id == chat.chatModelId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var temperature: some View {
        Menu("Temperature") {
            Button(action: {
                chat.temperature = nil
            }) {
                HStack {
                    Text(
                        "Default (\(defaultTemperature.formatted(.number.precision(.fractionLength(1)))))"
                    )
                    if chat.temperature == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Divider()

            ForEach(Array(stride(from: 0.0, through: 2.0, by: 0.1)), id: \.self) { value in
                Button(action: {
                    chat.temperature = value
                }) {
                    HStack {
                        Text("\(value.formatted(.number.precision(.fractionLength(1))))")
                        if value == chat.temperature {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
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


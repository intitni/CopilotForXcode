import AppKit
import ComposableArchitecture
import SharedUIComponents
import SwiftUI

struct ChatTabItemView: View {
    let chat: StoreOf<Chat>

    var body: some View {
        WithViewStore(chat, observe: \.title) { viewStore in
            Text(viewStore.state)
        }
    }
}

struct ChatContextMenu: View {
    let store: StoreOf<ChatMenu>
    @AppStorage(\.customCommands) var customCommands
    @AppStorage(\.chatModels) var chatModels
    @AppStorage(\.defaultChatFeatureChatModelId) var defaultChatModelId
    @AppStorage(\.chatGPTTemperature) var defaultTemperature

    var body: some View {
        currentSystemPrompt
            .onAppear { store.send(.appear) }
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
        WithViewStore(store, observe: \.systemPrompt) { viewStore in
            Text({
                var text = viewStore.state
                if text.isEmpty { text = "N/A" }
                if text.count > 30 { text = String(text.prefix(30)) + "..." }
                return text
            }() as String)
        }
    }

    @ViewBuilder
    var currentExtraSystemPrompt: some View {
        Text("Extra Prompt:")
        WithViewStore(store, observe: \.extraSystemPrompt) { viewStore in
            Text({
                var text = viewStore.state
                if text.isEmpty { text = "N/A" }
                if text.count > 30 { text = String(text.prefix(30)) + "..." }
                return text
            }() as String)
        }
    }

    var resetPrompt: some View {
        Button("Reset System Prompt") {
            store.send(.resetPromptButtonTapped)
        }
    }

    @ViewBuilder
    var chatModel: some View {
        Menu("Chat Model") {
            WithViewStore(store, observe: \.chatModelIdOverride) { viewStore in
                Button(action: {
                    viewStore.send(.chatModelIdOverrideSelected(nil))
                }) {
                    HStack {
                        if let defaultModel = chatModels
                            .first(where: { $0.id == defaultChatModelId })
                        {
                            Text("Default (\(defaultModel.name))")
                            if viewStore.state == nil {
                                Image(systemName: "checkmark")
                            }
                        } else {
                            Text("No Model Available")
                        }
                    }
                }

                if let id = viewStore.state, !chatModels.map(\.id).contains(id) {
                    Button(action: {
                        viewStore.send(.chatModelIdOverrideSelected(nil))
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
                        viewStore.send(.chatModelIdOverrideSelected(model.id))
                    }) {
                        HStack {
                            Text(model.name)
                            if model.id == viewStore.state {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var temperature: some View {
        Menu("Temperature") {
            WithViewStore(store, observe: \.temperatureOverride) { viewStore in
                Button(action: {
                    viewStore.send(.temperatureOverrideSelected(nil))
                }) {
                    HStack {
                        Text(
                            "Default (\(defaultTemperature.formatted(.number.precision(.fractionLength(1)))))"
                        )
                        if viewStore.state == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(Array(stride(from: 0.0, through: 2.0, by: 0.1)), id: \.self) { value in
                    Button(action: {
                        viewStore.send(.temperatureOverrideSelected(value))
                    }) {
                        HStack {
                            Text("\(value.formatted(.number.precision(.fractionLength(1))))")
                            if value == viewStore.state {
                                Image(systemName: "checkmark")
                            }
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
                    store.send(.customCommandButtonTapped(command))
                }) {
                    Text(command.name)
                }
            }
        }
    }
}


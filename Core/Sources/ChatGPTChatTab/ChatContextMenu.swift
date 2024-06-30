import AppKit
import ChatService
import ComposableArchitecture
import SharedUIComponents
import SwiftUI

struct ChatTabItemView: View {
    let chat: StoreOf<Chat>

    var body: some View {
        WithPerceptionTracking {
            Text(chat.title)
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
        WithPerceptionTracking {
            currentSystemPrompt
                .onAppear { store.send(.appear) }
            currentExtraSystemPrompt
            resetPrompt

            Divider()

            chatModel
            temperature
            defaultScopes

            Divider()

            customCommandMenu
        }
    }

    @ViewBuilder
    var currentSystemPrompt: some View {
        Text("System Prompt:")
        Text({
            var text = store.systemPrompt
            if text.isEmpty { text = "N/A" }
            if text.count > 30 { text = String(text.prefix(30)) + "..." }
            return text
        }() as String)
    }

    @ViewBuilder
    var currentExtraSystemPrompt: some View {
        Text("Extra Prompt:")
        Text({
            var text = store.extraSystemPrompt
            if text.isEmpty { text = "N/A" }
            if text.count > 30 { text = String(text.prefix(30)) + "..." }
            return text
        }() as String)
    }

    var resetPrompt: some View {
        Button("Reset System Prompt") {
            store.send(.resetPromptButtonTapped)
        }
    }

    @ViewBuilder
    var chatModel: some View {
        let allModels = chatModels + [.init(
            id: "com.github.copilot",
            name: "GitHub Copilot (poc)",
            format: .openAI,
            info: .init()
        )]
        
        Menu("Chat Model") {
            Button(action: {
                store.send(.chatModelIdOverrideSelected(nil))
            }) {
                HStack {
                    if let defaultModel = allModels
                        .first(where: { $0.id == defaultChatModelId })
                    {
                        Text("Default (\(defaultModel.name))")
                        if store.chatModelIdOverride == nil {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Text("No Model Available")
                    }
                }
            }

            if let id = store.chatModelIdOverride, !allModels.map(\.id).contains(id) {
                Button(action: {
                    store.send(.chatModelIdOverrideSelected(nil))
                }) {
                    HStack {
                        Text("Default (Selected Model Not Found)")
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            ForEach(allModels, id: \.id) { model in
                Button(action: {
                    store.send(.chatModelIdOverrideSelected(model.id))
                }) {
                    HStack {
                        Text(model.name)
                        if model.id == store.chatModelIdOverride {
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
                store.send(.temperatureOverrideSelected(nil))
            }) {
                HStack {
                    Text(
                        "Default (\(defaultTemperature.formatted(.number.precision(.fractionLength(1)))))"
                    )
                    if store.temperatureOverride == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            ForEach(Array(stride(from: 0.0, through: 2.0, by: 0.1)), id: \.self) { value in
                Button(action: {
                    store.send(.temperatureOverrideSelected(value))
                }) {
                    HStack {
                        Text("\(value.formatted(.number.precision(.fractionLength(1))))")
                        if value == store.temperatureOverride {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var defaultScopes: some View {
        Menu("Default Scopes") {
            Button(action: {
                store.send(.resetDefaultScopesButtonTapped)
            }) {
                Text("Reset Default Scopes")
            }

            Divider()

            ForEach(ChatService.Scope.allCases, id: \.rawValue) { value in
                Button(action: {
                    store.send(.toggleScope(value))
                }) {
                    HStack {
                        Text("@" + value.rawValue)
                        if store.defaultScopes.contains(value) {
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
                    store.send(.customCommandButtonTapped(command))
                }) {
                    Text(command.name)
                }
            }
        }
    }
}


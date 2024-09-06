import ComposableArchitecture
import MarkdownUI
import Preferences
import SwiftUI

@MainActor
struct EditCustomCommandView: View {
    @Environment(\.toast) var toast
    @Perception.Bindable var store: StoreOf<EditCustomCommand>

    init(store: StoreOf<EditCustomCommand>) {
        self.store = store
    }

    var body: some View {
        ScrollView {
            Form {
                sharedForm
                featureSpecificForm
            }.padding()
        }.safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    @ViewBuilder var sharedForm: some View {
        WithPerceptionTracking {
            TextField("Name", text: $store.name)

            Picker("Command Type", selection: $store.commandType) {
                ForEach(
                    EditCustomCommand.CommandType.allCases,
                    id: \.rawValue
                ) { commandType in
                    Text({
                        switch commandType {
                        case .sendMessage:
                            return "Send Message"
                        case .promptToCode:
                            return "Modification"
                        case .customChat:
                            return "Custom Chat"
                        case .singleRoundDialog:
                            return "Single Round Dialog"
                        }
                    }() as String).tag(commandType)
                }
            }
        }
    }

    @ViewBuilder var featureSpecificForm: some View {
        WithPerceptionTracking {
            switch store.commandType {
            case .sendMessage:
                EditSendMessageCommandView(
                    store: store.scope(
                        state: \.sendMessage,
                        action: \.sendMessage
                    )
                )
            case .promptToCode:
                EditPromptToCodeCommandView(
                    store: store.scope(
                        state: \.promptToCode,
                        action: \.promptToCode
                    )
                )
            case .customChat:
                EditCustomChatCommandView(
                    store: store.scope(
                        state: \.customChat,
                        action: \.customChat
                    )
                )
            case .singleRoundDialog:
                EditSingleRoundDialogCommandView(
                    store: store.scope(
                        state: \.singleRoundDialog,
                        action: \.singleRoundDialog
                    )
                )
            }
        }
    }

    @ViewBuilder var bottomBar: some View {
        WithPerceptionTracking {
            VStack {
                Divider()
                
                VStack(alignment: .trailing) {
                    Text(
                        "After renaming or adding a custom command, please restart Xcode to refresh the menu."
                    )
                    .foregroundStyle(.secondary)
                    
                    HStack {
                        Spacer()
                        Button("Close") {
                            store.send(.close)
                        }
                        
                        if store.isNewCommand {
                            Button("Add") {
                                store.send(.saveCommand)
                            }
                        } else {
                            Button("Save") {
                                store.send(.saveCommand)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
            .background(.regularMaterial)
        }
    }
}

struct EditSendMessageCommandView: View {
    @Perception.Bindable var store: StoreOf<EditSendMessageCommand>

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Extra System Prompt", isOn: $store.useExtraSystemPrompt)
                EditableText(text: $store.extraSystemPrompt)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                EditableText(text: $store.prompt)
            }
            .padding(.vertical, 4)
        }
    }
}

struct EditPromptToCodeCommandView: View {
    @Perception.Bindable var store: StoreOf<EditPromptToCodeCommand>

    var body: some View {
        WithPerceptionTracking {
            Toggle("Continuous Mode", isOn: $store.continuousMode)
            Toggle("Generate Description", isOn: $store.generateDescription)

            VStack(alignment: .leading, spacing: 4) {
                Text("Extra Context")
                EditableText(text: $store.extraSystemPrompt)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                EditableText(text: $store.prompt)
            }
            .padding(.vertical, 4)
        }
    }
}

struct EditCustomChatCommandView: View {
    @Perception.Bindable var store: StoreOf<EditCustomChatCommand>

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt")
                EditableText(text: $store.systemPrompt)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                EditableText(text: $store.prompt)
            }
            .padding(.vertical, 4)
        }
    }
}

struct EditSingleRoundDialogCommandView: View {
    @Perception.Bindable var store: StoreOf<EditSingleRoundDialogCommand>

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt")
                EditableText(text: $store.systemPrompt)
            }
            .padding(.vertical, 4)

            Picker(selection: $store.overwriteSystemPrompt) {
                Text("Append to Default System Prompt").tag(false)
                Text("Overwrite Default System Prompt").tag(true)
            } label: {
                Text("Mode")
            }
            .pickerStyle(.radioGroup)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                EditableText(text: $store.prompt)
            }
            .padding(.vertical, 4)

            Toggle("Receive Reply in Notification", isOn: $store.receiveReplyInNotification)
            Text(
                "You will be prompted to grant the app permission to send notifications for the first time."
            )
            .font(.footnote)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct EditCustomCommandView_Preview: PreviewProvider {
    static var previews: some View {
        EditCustomCommandView(
            store: .init(
                initialState: .init(.init(
                    commandId: "4",
                    name: "Explain Code",
                    feature: .promptToCode(
                        extraSystemPrompt: nil,
                        prompt: "Hello",
                        continuousMode: false,
                        generateDescription: true
                    )
                )),
                reducer: {
                    EditCustomCommand(
                        settings: .init(customCommands: .init(
                            wrappedValue: [],
                            "CustomCommandView_Preview"
                        ))
                    )
                }
            )
        )
        .frame(width: 800)
    }
}

struct EditSingleRoundDialogCommandView_Preview: PreviewProvider {
    static var previews: some View {
        EditSingleRoundDialogCommandView(store: .init(
            initialState: .init(),
            reducer: { EditSingleRoundDialogCommand() }
        ))
        .frame(width: 800, height: 600)
    }
}


import ComposableArchitecture
import MarkdownUI
import Preferences
import SwiftUI

@MainActor
struct EditCustomCommandView: View {
    @Environment(\.toast) var toast
    let store: StoreOf<EditCustomCommand>

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
        WithViewStore(store, observe: { $0 }) { viewStore in
            TextField("Name", text: viewStore.$name)

            Picker("Command Type", selection: viewStore.$commandType) {
                ForEach(
                    EditCustomCommand.CommandType.allCases,
                    id: \.rawValue
                ) { commandType in
                    Text({
                        switch commandType {
                        case .sendMessage:
                            return "Send Message"
                        case .promptToCode:
                            return "Prompt to Code"
                        case .customChat:
                            return "Custom Chat"
                        case .oneTimeDialog:
                            return "One-time Dialog"
                        }
                    }() as String).tag(commandType)
                }
            }
        }
    }

    @ViewBuilder var featureSpecificForm: some View {
        WithViewStore(
            store,
            observe: { $0.commandType }
        ) { viewStore in
            switch viewStore.state {
            case .sendMessage:
                EditSendMessageCommandView(
                    store: store.scope(
                        state: \.sendMessage,
                        action: EditCustomCommand.Action.sendMessage
                    )
                )
            case .promptToCode:
                EditPromptToCodeCommandView(
                    store: store.scope(
                        state: \.promptToCode,
                        action: EditCustomCommand.Action.promptToCode
                    )
                )
            case .customChat:
                EditCustomChatCommandView(
                    store: store.scope(
                        state: \.customChat,
                        action: EditCustomCommand.Action.customChat
                    )
                )
            case .oneTimeDialog:
                EditOneTimeDialogCommandView(
                    store: store.scope(
                        state: \.oneTimeDialog,
                        action: EditCustomCommand.Action.oneTimeDialog
                    )
                )
            }
        }
    }

    @ViewBuilder var bottomBar: some View {
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

                    WithViewStore(store, observe: { $0.isNewCommand }) { viewStore in
                        if viewStore.state {
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
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
        .background(.regularMaterial)
    }
}

struct EditSendMessageCommandView: View {
    let store: StoreOf<EditSendMessageCommand>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Extra System Prompt", isOn: viewStore.$useExtraSystemPrompt)
                EditableText(text: viewStore.$extraSystemPrompt)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                EditableText(text: viewStore.$prompt)
            }
            .padding(.vertical, 4)
        }
    }
}

struct EditPromptToCodeCommandView: View {
    let store: StoreOf<EditPromptToCodeCommand>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Toggle("Continuous Mode", isOn: viewStore.$continuousMode)
            Toggle("Generate Description", isOn: viewStore.$generateDescription)

            VStack(alignment: .leading, spacing: 4) {
                Text("Extra Context")
                EditableText(text: viewStore.$extraSystemPrompt)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                EditableText(text: viewStore.$prompt)
            }
            .padding(.vertical, 4)
        }
    }
}

struct EditCustomChatCommandView: View {
    let store: StoreOf<EditCustomChatCommand>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt")
                EditableText(text: viewStore.$systemPrompt)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                EditableText(text: viewStore.$prompt)
            }
            .padding(.vertical, 4)
        }
    }
}

struct EditOneTimeDialogCommandView: View {
    let store: StoreOf<EditOneTimeDialogCommand>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt")
                EditableText(text: viewStore.$systemPrompt)
            }
            .padding(.vertical, 4)

            Picker(selection: viewStore.$overwriteSystemPrompt) {
                Text("Append to Default System Prompt").tag(false)
                Text("Overwrite Default System Prompt").tag(true)
            } label: {
                Text("Mode")
            }
            .pickerStyle(.radioGroup)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                EditableText(text: viewStore.$prompt)
            }
            .padding(.vertical, 4)

            Toggle("Receive Reply in Notification", isOn: viewStore.$receiveReplyInNotification)
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
                reducer: EditCustomCommand(
                    settings: .init(customCommands: .init(
                        wrappedValue: [],
                        "CustomCommandView_Preview"
                    )),
                    toast: { _, _ in }
                )
            )
        )
        .frame(width: 800)
    }
}

struct EditOneTimeDialogCommandView_Preview: PreviewProvider {
    static var previews: some View {
        EditOneTimeDialogCommandView(store: .init(
            initialState: .init(),
            reducer: EditOneTimeDialogCommand()
        ))
        .frame(width: 800, height: 600)
    }
}


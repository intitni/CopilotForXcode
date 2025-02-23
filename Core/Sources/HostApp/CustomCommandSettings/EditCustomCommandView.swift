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
                    ),
                    attachmentStore: store.scope(
                        state: \.attachments,
                        action: \.attachments
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
                    ),
                    attachmentStore: store.scope(
                        state: \.attachments,
                        action: \.attachments
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

struct CustomCommandAttachmentPickerView: View {
    @Perception.Bindable var store: StoreOf<EditCustomCommandAttachment>
    @State private var isFileInputPresented = false
    @State private var filePath = ""

    #if canImport(ProHostApp)
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading) {
                Text("Contexts")

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        if store.attachments.isEmpty {
                            Text("No context")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(store.attachments, id: \.kind) { attachment in
                                HStack {
                                    switch attachment.kind {
                                    case let .file(path: path):
                                        HStack {
                                            Text("File:")
                                            Text(path).foregroundStyle(.secondary)
                                        }
                                    default:
                                        Text(attachment.kind.description)
                                    }
                                    Spacer()
                                    Button {
                                        store.attachments.removeAll { $0.kind == attachment.kind }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(minWidth: 240)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.separator, lineWidth: 1)
                    }

                    Form {
                        Menu {
                            ForEach(CustomCommand.Attachment.Kind.allCases.filter { kind in
                                !store.attachments.contains { $0.kind == kind }
                            }, id: \.self) { kind in
                                if kind == .file(path: "") {
                                    Button {
                                        isFileInputPresented = true
                                    } label: {
                                        Text("File...")
                                    }
                                } else {
                                    Button {
                                        store.attachments.append(.init(kind: kind))
                                    } label: {
                                        Text(kind.description)
                                    }
                                }
                            }
                        } label: {
                            Label("Add context", systemImage: "plus")
                        }

                        Toggle(
                            "Ignore existing contexts",
                            isOn: $store.ignoreExistingAttachments
                        )
                    }
                }
            }
            .sheet(isPresented: $isFileInputPresented) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Enter file path:")
                        .font(.headline)
                    Text(
                        "You can enter either an absolute path or a path relative to the project root."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    TextField("File path", text: $filePath)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            isFileInputPresented = false
                            filePath = ""
                        }
                        Button("Add") {
                            store.attachments.append(.init(kind: .file(path: filePath)))
                            isFileInputPresented = false
                            filePath = ""
                        }
                        .disabled(filePath.isEmpty)
                    }
                }
                .padding()
                .frame(minWidth: 400)
            }
        }
    }
    #else
    var body: some View { EmptyView() }
    #endif
}

extension CustomCommand.Attachment.Kind {
    public static var allCases: [CustomCommand.Attachment.Kind] {
        [
            .activeDocument,
            .debugArea,
            .clipboard,
            .senseScope,
            .projectScope,
            .webScope,
            .gitStatus,
            .gitLog,
            .file(path: ""),
        ]
    }

    var description: String {
        switch self {
        case .activeDocument: return "Active Document"
        case .debugArea: return "Debug Area"
        case .clipboard: return "Clipboard"
        case .senseScope: return "Sense Scope"
        case .projectScope: return "Project Scope"
        case .webScope: return "Web Scope"
        case .gitStatus: return "Git Status and Diff"
        case .gitLog: return "Git Log"
        case .file: return "File"
        }
    }
}

struct EditSendMessageCommandView: View {
    @Perception.Bindable var store: StoreOf<EditSendMessageCommand>
    var attachmentStore: StoreOf<EditCustomCommandAttachment>

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Extra Context", isOn: $store.useExtraSystemPrompt)
                EditableText(text: $store.extraSystemPrompt)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Send immediately")
                EditableText(text: $store.prompt)
            }
            .padding(.vertical, 4)

            CustomCommandAttachmentPickerView(store: attachmentStore)
                .padding(.vertical, 4)
        }
    }
}

struct EditPromptToCodeCommandView: View {
    @Perception.Bindable var store: StoreOf<EditPromptToCodeCommand>

    var body: some View {
        WithPerceptionTracking {
            Toggle("Continuous Mode", isOn: $store.continuousMode)

            VStack(alignment: .leading, spacing: 4) {
                Text("Extra Context")
                EditableText(text: $store.extraSystemPrompt)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Instruction")
                EditableText(text: $store.prompt)
            }
            .padding(.vertical, 4)
        }
    }
}

struct EditCustomChatCommandView: View {
    @Perception.Bindable var store: StoreOf<EditCustomChatCommand>
    var attachmentStore: StoreOf<EditCustomCommandAttachment>

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 4) {
                Text("Topic")
                EditableText(text: $store.systemPrompt)
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Send immediately")
                EditableText(text: $store.prompt)
            }
            .padding(.vertical, 4)

            CustomCommandAttachmentPickerView(store: attachmentStore)
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
                Text("Append to default system prompt").tag(false)
                Text("Overwrite default system prompt").tag(true)
            } label: {
                Text("Mode")
            }
            .pickerStyle(.radioGroup)

            VStack(alignment: .leading, spacing: 4) {
                Text("Prompt")
                EditableText(text: $store.prompt)
            }
            .padding(.vertical, 4)

            Toggle("Receive response in notification", isOn: $store.receiveReplyInNotification)
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
                    ),
                    ignoreExistingAttachments: false,
                    attachments: [] as [CustomCommand.Attachment]
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


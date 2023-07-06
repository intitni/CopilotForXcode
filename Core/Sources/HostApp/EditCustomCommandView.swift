import Preferences
import SwiftUI

struct EditCustomCommandView: View {
    @Environment(\.toast) var toast
    @Binding var editingCommand: CustomCommandView.EditingCommand?
    var settings: CustomCommandView.Settings
    let originalName: String
    @State var commandType: CommandType

    @State var name: String
    @State var prompt: String
    @State var systemPrompt: String
    @State var usePrompt: Bool
    @State var continuousMode: Bool
    @State var editingContentInFullScreen: Binding<String>?
    @State var generatingPromptToCodeDescription: Bool
    @State var oneTimeDialogOverwriteSystemPrompt: Bool = false
    @State var oneTimeDialogReceiveReplyInNotification: Bool = false

    enum CommandType: Int, CaseIterable {
        case chatWithSelection
        case promptToCode
        case customChat
        case oneTimeDialog
    }

    init(
        editingCommand: Binding<CustomCommandView.EditingCommand?>,
        settings: CustomCommandView.Settings
    ) {
        _editingCommand = editingCommand
        self.settings = settings
        originalName = editingCommand.wrappedValue?.command.name ?? ""
        name = originalName
        switch editingCommand.wrappedValue?.command.feature {
        case let .chatWithSelection(extraSystemPrompt, prompt, useExtraSystemPrompt):
            commandType = .chatWithSelection
            self.prompt = prompt ?? ""
            systemPrompt = extraSystemPrompt ?? ""
            usePrompt = useExtraSystemPrompt ?? true
            continuousMode = false
            generatingPromptToCodeDescription = true
        case let .customChat(systemPrompt, prompt):
            commandType = .customChat
            self.systemPrompt = systemPrompt ?? ""
            self.prompt = prompt ?? ""
            usePrompt = false
            continuousMode = false
            generatingPromptToCodeDescription = true
        case let .promptToCode(extraSystemPrompt, prompt, continuousMode, generateDescription):
            commandType = .promptToCode
            self.prompt = prompt ?? ""
            systemPrompt = extraSystemPrompt ?? ""
            usePrompt = false
            self.continuousMode = continuousMode ?? false
            generatingPromptToCodeDescription = generateDescription ?? true
        case let .oneTimeDialog(
            systemPrompt,
            overwriteSystemPrompt,
            prompt,
            receiveReplyInNotification
        ):
            commandType = .oneTimeDialog
            self.systemPrompt = systemPrompt ?? ""
            self.prompt = prompt ?? ""
            usePrompt = false
            continuousMode = false
            generatingPromptToCodeDescription = true
            oneTimeDialogOverwriteSystemPrompt = overwriteSystemPrompt ?? false
            oneTimeDialogReceiveReplyInNotification = receiveReplyInNotification ?? true
        case .none:
            commandType = .chatWithSelection
            prompt = ""
            systemPrompt = ""
            continuousMode = false
            usePrompt = true
            generatingPromptToCodeDescription = true
        }
    }

    var body: some View {
        ScrollView {
            Form {
                TextField("Name", text: $name)

                Picker("Command Type", selection: $commandType) {
                    ForEach(CommandType.allCases, id: \.rawValue) { commandType in
                        Text({
                            switch commandType {
                            case .chatWithSelection:
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

                switch commandType {
                case .chatWithSelection:
                    systemPromptTextField(title: "Extra System Prompt", hasToggle: true)
                    promptTextField
                case .promptToCode:
                    continuousModeToggle
                    generateDescriptionToggle
                    systemPromptTextField(title: "Extra System Prompt", hasToggle: false)
                    promptTextField
                case .customChat:
                    systemPromptTextField(hasToggle: false)
                    promptTextField
                case .oneTimeDialog:
                    systemPromptTextField(title: "System Prompt", hasToggle: false)
                    oneTimeDialogOverwriteSystemPromptToggle
                    promptTextField
                    oneTimeDialogReceiveReplyInNotificationToggle
                }
            }.padding()
        }.safeAreaInset(edge: .bottom) {
            VStack {
                Divider()

                VStack {
                    Text(
                        "After renaming or adding a custom command, please restart Xcode to refresh the menu."
                    )
                    .foregroundStyle(.secondary)

                    HStack {
                        Spacer()
                        Button("Close") {
                            editingCommand = nil
                        }

                        lazy var newCommand = CustomCommand(
                            commandId: editingCommand?.command.id ?? UUID().uuidString,
                            name: name,
                            feature: {
                                switch commandType {
                                case .chatWithSelection:
                                    return .chatWithSelection(
                                        extraSystemPrompt: systemPrompt,
                                        prompt: prompt,
                                        useExtraSystemPrompt: usePrompt
                                    )
                                case .promptToCode:
                                    return .promptToCode(
                                        extraSystemPrompt: systemPrompt,
                                        prompt: prompt,
                                        continuousMode: continuousMode,
                                        generateDescription: generatingPromptToCodeDescription
                                    )
                                case .customChat:
                                    return .customChat(
                                        systemPrompt: systemPrompt,
                                        prompt: prompt
                                    )
                                case .oneTimeDialog:
                                    return .oneTimeDialog(
                                        systemPrompt: systemPrompt,
                                        overwriteSystemPrompt: oneTimeDialogOverwriteSystemPrompt,
                                        prompt: prompt,
                                        receiveReplyInNotification: oneTimeDialogReceiveReplyInNotification
                                    )
                                }
                            }()
                        )

                        if editingCommand?.isNew ?? true {
                            Button("Add") {
                                guard !newCommand.name.isEmpty else {
                                    toast(Text("Command name cannot be empty."), .error)
                                    return
                                }
                                settings.customCommands.append(newCommand)
                                editingCommand?.isNew = false
                                editingCommand?.command = newCommand

                                toast(Text("The command is created."), .info)
                            }
                        } else {
                            Button("Save") {
                                guard !newCommand.name.isEmpty else {
                                    toast(Text("Command name cannot be empty."), .error)
                                    return
                                }

                                if let index = settings.customCommands.firstIndex(where: {
                                    $0.id == newCommand.id
                                }) {
                                    settings.customCommands[index] = newCommand
                                } else {
                                    settings.customCommands.append(newCommand)
                                }

                                toast(Text("The command is updated."), .info)
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

    @ViewBuilder
    var promptTextField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Prompt")
            EditableText(text: $prompt)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    func systemPromptTextField(title: String? = nil, hasToggle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if hasToggle {
                Toggle(title ?? "System Prompt", isOn: $usePrompt)
            } else {
                Text(title ?? "System Prompt")
            }
            EditableText(text: $systemPrompt)
        }
        .padding(.vertical, 4)
    }

    var continuousModeToggle: some View {
        Toggle("Continuous Mode", isOn: $continuousMode)
    }

    var generateDescriptionToggle: some View {
        Toggle("Generate Description", isOn: $generatingPromptToCodeDescription)
    }

    var oneTimeDialogOverwriteSystemPromptToggle: some View {
        Picker(selection: $oneTimeDialogOverwriteSystemPrompt) {
            Text("Append to Default System Prompt").tag(false)
            Text("Overwrite Default System Prompt").tag(true)
        } label: {
            Text("Mode")
        }
        .pickerStyle(.radioGroup)
    }

    var oneTimeDialogReceiveReplyInNotificationToggle: some View {
        Toggle("Receive Reply in Notification", isOn: $oneTimeDialogReceiveReplyInNotification)
    }
}

// MARK: - Preview

struct EditCustomCommandView_Preview: PreviewProvider {
    static var previews: some View {
        EditCustomCommandView(
            editingCommand: .constant(CustomCommandView.EditingCommand(
                isNew: false,
                command: .init(
                    commandId: "4",
                    name: "Explain Code",
                    feature: .promptToCode(
                        extraSystemPrompt: nil,
                        prompt: "Hello",
                        continuousMode: false,
                        generateDescription: true
                    )
                )
            )),
            settings: .init(customCommands: .init(wrappedValue: [], "CustomCommandView_Preview"))
        )
        .frame(width: 800)
    }
}


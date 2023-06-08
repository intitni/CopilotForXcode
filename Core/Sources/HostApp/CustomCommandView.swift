import Preferences
import SwiftUI

extension List {
    @ViewBuilder
    func removeBackground() -> some View {
        if #available(macOS 13.0, *) {
            scrollContentBackground(.hidden)
        } else {
            background(Color.clear)
        }
    }
}

struct CustomCommandView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.customCommands) var customCommands
        var illegalNames: [String] {
            let existed = customCommands.map(\.name)
            let builtin: [String] = [
                "Get Suggestions",
                "Accept Suggestion",
                "Reject Suggestion",
                "Next Suggestion",
                "Previous Suggestion",
                "Real-time Suggestions",
                "Prefetch Suggestions",
                "Open Chat",
                "Prompt to Code",
            ]

            return existed + builtin
        }

        init(customCommands: AppStorage<[CustomCommand]>? = nil) {
            if let list = customCommands {
                _customCommands = list
            }
        }
    }

    struct EditingCommand {
        var isNew: Bool
        var command: CustomCommand
    }

    @State var editingCommand: EditingCommand?

    @StateObject var settings = Settings()

    var body: some View {
        HStack(spacing: 0) {
            List {
                ForEach(settings.customCommands, id: \.name) { command in
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal")

                        VStack(alignment: .leading) {
                            Text(command.name)
                                .foregroundStyle(.primary)

                            Group {
                                switch command.feature {
                                case .chatWithSelection:
                                    Text("Open Chat")
                                case .customChat:
                                    Text("Custom Chat")
                                case .promptToCode:
                                    Text("Prompt to Code")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingCommand = .init(isNew: false, command: command)
                        }
                    }
                    .padding(4)
                    .background(
                        editingCommand?.command.id == command.id
                            ? Color.primary.opacity(0.05)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 4)
                    )
                    .contextMenu {
                        Button("Remove") {
                            settings.customCommands.removeAll(
                                where: { $0.id == command.id }
                            )
                            if let editingCommand, editingCommand.command.id == command.id {
                                self.editingCommand = nil
                            }
                        }
                    }
                }
                .onMove(perform: { indices, newOffset in
                    settings.customCommands.move(fromOffsets: indices, toOffset: newOffset)
                })
            }
            .removeBackground()
            .padding(.vertical, 4)
            .listStyle(.plain)
            .frame(width: 200)
            .background(Color.primary.opacity(0.05))
            .overlay {
                if settings.customCommands.isEmpty {
                    Text("""
                    Empty
                    Add command with "+" button
                    """)
                    .multilineTextAlignment(.center)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    editingCommand = .init(isNew: true, command: CustomCommand(
                        commandId: UUID().uuidString,
                        name: "New Command",
                        feature: .chatWithSelection(
                            extraSystemPrompt: nil,
                            prompt: "Tell me about the code.",
                            useExtraSystemPrompt: false
                        )
                    ))
                }) {
                    Text(Image(systemName: "plus.circle.fill")) + Text(" New Command")
                }
                .buttonStyle(.plain)
                .padding()
            }

            Divider()

            if let editingCommand {
                EditCustomCommandView(
                    editingCommand: $editingCommand,
                    settings: settings
                ).id(editingCommand.command.id)
            } else {
                Color.clear
            }
        }
    }
}

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

    enum CommandType: Int, CaseIterable {
        case chatWithSelection
        case promptToCode
        case customChat
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
                                return "Open Chat"
                            case .promptToCode:
                                return "Prompt to Code"
                            case .customChat:
                                return "Custom Chat"
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
                                }
                            }()
                        )

                        if editingCommand?.isNew ?? true {
                            Button("Add") {
                                guard !settings.illegalNames.contains(newCommand.name) else {
                                    toast(Text("Command name is illegal."), .error)
                                    return
                                }
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
                                guard !settings.illegalNames.contains(newCommand.name)
                                    || newCommand.name == originalName
                                else {
                                    toast(Text("Command name is illegal."), .error)
                                    return
                                }
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
}

// MARK: - Previews

struct CustomCommandView_Preview: PreviewProvider {
    static var previews: some View {
        CustomCommandView(
            editingCommand: .init(isNew: false, command: .init(
                commandId: "1",
                name: "Explain Code",
                feature: .chatWithSelection(
                    extraSystemPrompt: nil,
                    prompt: "Hello",
                    useExtraSystemPrompt: false
                )
            )),
            settings: .init(customCommands: .init(wrappedValue: [
                .init(
                    commandId: "1",
                    name: "Explain Code",
                    feature: .chatWithSelection(
                        extraSystemPrompt: nil,
                        prompt: "Hello",
                        useExtraSystemPrompt: false
                    )
                ),
                .init(
                    commandId: "2",
                    name: "Refactor Code",
                    feature: .promptToCode(
                        extraSystemPrompt: nil,
                        prompt: "Refactor",
                        continuousMode: false,
                        generateDescription: true
                    )
                ),
            ], "CustomCommandView_Preview"))
        )
    }
}

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


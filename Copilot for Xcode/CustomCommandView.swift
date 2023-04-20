import Preferences
import SwiftUI

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
                "Toggle Real-time Suggestions",
                "Real-time Suggestions",
                "Prefetch Suggestions",
                "Chat with Selection",
                "Prompt to Code",
                "# Custom Commands:",
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

    var isOpen: Binding<Bool>
    @State var editingCommand: EditingCommand?
    var isEditPanelPresented: Binding<Bool> {
        .init(
            get: { editingCommand != nil },
            set: { newValue in
                if !newValue {
                    editingCommand = nil
                }
            }
        )
    }

    @StateObject var settings = Settings()

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    self.isOpen.wrappedValue = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .buttonStyle(.plain)
                Text("Custom Commands")
                Spacer()
                Button(action: {
                    editingCommand = .init(isNew: true, command: CustomCommand(
                        name: "New Command",
                        feature: .chatWithSelection(prompt: "Tell me about the code.")
                    ))
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .buttonStyle(.plain)
            }
            .background(.black.opacity(0.2))

            List {
                ForEach(settings.customCommands, id: \.name) { command in
                    HStack {
                        Text(command.name)

                        Spacer()

                        Group {
                            switch command.feature {
                            case .chatWithSelection:
                                Text("Chat with Selection")
                            case .customChat:
                                Text("Custom Chat")
                            case .promptToCode:
                                Text("Prompt to Code")
                            }
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingCommand = .init(isNew: false, command: command)
                    }
                    .contextMenu {
                        Button("Remove") {
                            settings.customCommands.removeAll(
                                where: { $0.name == command.name }
                            )
                        }
                    }
                }
            }
            .overlay {
                if settings.customCommands.isEmpty {
                    Text("""
                    Empty
                    Add command with "+" button
                    """)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .frame(width: 500, height: 500)
        .sheet(isPresented: isEditPanelPresented) {
            EditCustomCommandView(
                editingCommand: $editingCommand,
                settings: settings
            )
        }
    }
}

struct EditCustomCommandView: View {
    @Binding var editingCommand: CustomCommandView.EditingCommand?
    var settings: CustomCommandView.Settings
    let originalName: String
    @State var commandType: CommandType

    @State var name: String
    @State var prompt: String
    @State var systemPrompt: String
    @State var continuousMode: Bool
    @State var errorMessage: String?

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
        case let .chatWithSelection(prompt):
            commandType = .chatWithSelection
            self.prompt = prompt ?? ""
            self.systemPrompt = ""
            self.continuousMode = false
        case let .customChat(systemPrompt, prompt):
            commandType = .customChat
            self.systemPrompt = systemPrompt ?? ""
            self.prompt = prompt ?? ""
            self.continuousMode = false
        case let .promptToCode(prompt, continuousMode):
            commandType = .promptToCode
            self.prompt = prompt ?? ""
            self.systemPrompt = ""
            self.continuousMode = continuousMode ?? false
        case .none:
            commandType = .chatWithSelection
            self.prompt = ""
            self.systemPrompt = ""
            self.continuousMode = false
        }
    }

    var body: some View {
        VStack {
            Form {
                TextField("Name", text: $name)

                Picker("Command Type", selection: $commandType) {
                    ForEach(CommandType.allCases, id: \.rawValue) { commandType in
                        Text({
                            switch commandType {
                            case .chatWithSelection:
                                return "Chat with Selection"
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
                    promptTextField
                case .promptToCode:
                    promptTextField
                    continuousModeToggle
                case .customChat:
                    systemPromptTextField
                    promptTextField
                }
            }
            
            Text(
                "After renaming or adding a custom command, please restart Xcode to refresh the menu."
            )
            .foregroundStyle(.secondary)
            .padding()

            HStack {
                Spacer()
                Button("Cancel") {
                    editingCommand = nil
                }

                lazy var newCommand = CustomCommand(
                    name: name,
                    feature: {
                        switch commandType {
                        case .chatWithSelection:
                            return .chatWithSelection(prompt: prompt)
                        case .promptToCode:
                            return .promptToCode(prompt: prompt, continuousMode: continuousMode)
                        case .customChat:
                            return .customChat(systemPrompt: systemPrompt, prompt: prompt)
                        }
                    }()
                )

                if editingCommand?.isNew ?? true {
                    Button("Add") {
                        guard !settings.illegalNames.contains(newCommand.name) else {
                            errorMessage = "Command name is illegal."
                            return
                        }
                        guard !newCommand.name.isEmpty else {
                            errorMessage = "Command name cannot be empty."
                            return
                        }
                        settings.customCommands.append(newCommand)
                        editingCommand = nil
                    }
                } else {
                    Button("Update") {
                        guard let command = editingCommand?.command else { return }
                        guard !settings.illegalNames.contains(newCommand.name)
                            || newCommand.name == originalName
                        else {
                            errorMessage = "Command name is illegal."
                            return
                        }
                        guard !newCommand.name.isEmpty else {
                            errorMessage = "Command name cannot be empty."
                            return
                        }

                        if let index = settings.customCommands.firstIndex(where: {
                            $0.name == originalName
                        }) {
                            settings.customCommands[index] = newCommand
                        } else {
                            settings.customCommands.append(newCommand)
                        }
                        editingCommand = nil
                    }
                }
            }.buttonStyle(.copilot)

            if let errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
        }
        .padding()
        .frame(minWidth: 500)
    }

    var promptTextField: some View {
        TextField("Prompt", text: $prompt)
            .lineLimit(0)
    }

    var systemPromptTextField: some View {
        TextField("System Prompt", text: $systemPrompt)
            .lineLimit(0)
    }

    var continuousModeToggle: some View {
        Toggle("Continuous Mode", isOn: $continuousMode)
    }
}

// MARK: - Previews

struct CustomCommandView_Preview: PreviewProvider {
    static var previews: some View {
        CustomCommandView(
            isOpen: .constant(true),
            settings: .init(customCommands: .init(wrappedValue: [
                .init(name: "Explain Code", feature: .chatWithSelection(prompt: "Hello")),
                .init(
                    name: "Refactor Code",
                    feature: .promptToCode(prompt: "Refactor", continuousMode: false)
                ),
                .init(
                    name: "Tell Me A Joke",
                    feature: .customChat(systemPrompt: "Joke", prompt: "")
                ),
            ], "CustomCommandView_Preview"))
        )
        .background(.purple)
    }
}

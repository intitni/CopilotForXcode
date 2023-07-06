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
                                    Text("Send Message")
                                case .customChat:
                                    Text("Custom Chat")
                                case .promptToCode:
                                    Text("Prompt to Code")
                                case .oneTimeDialog:
                                    Text("One-time Dialog")
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


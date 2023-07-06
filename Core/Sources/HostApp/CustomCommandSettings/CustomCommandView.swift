import ComposableArchitecture
import MarkdownUI
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
    @Environment(\.toast) var toast

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
                    store: .init(
                        initialState: .init(editingCommand),
                        reducer: EditCustomCommand(
                            settings: settings,
                            toast: toast,
                            editingCommand: $editingCommand
                        )
                    )
                ).id(editingCommand.command.id)
            } else {
                CustomCommandTypeDescription(text: """
                # Send Message

                This command sends a message to the active chat tab. You can provide additional context through the "Extra System Prompt" as well.

                # Prompt to Code

                This command opens the prompt-to-code panel and executes the provided requirements on the selected code. You can provide additional context through the "Extra Context" as well.

                # Custom Chat

                This command will overwrite the system prompt to let the bot behave differently.

                # One-time Dialog

                This command allows you to send a message to a temporary chat without opening the chat panel.

                It is particularly useful for one-time commands, such as running a terminal command with `/run`.

                For example, you can set the prompt to `/run open $FILE_PATH -a "Finder.app"` to reveal the active document in Finder.
                """)
            }
        }
    }
}

struct CustomCommandTypeDescription: View {
    let text: String
    var body: some View {
        ScrollView {
            Markdown(text)
                .lineLimit(nil)
                .markdownTheme(
                    .gitHub
                        .text {
                            ForegroundColor(.secondary)
                            BackgroundColor(.clear)
                            FontSize(14)
                        }
                        .heading1 { conf in
                            VStack(alignment: .leading, spacing: 0) {
                                conf.label
                                    .relativePadding(.bottom, length: .em(0.3))
                                    .relativeLineSpacing(.em(0.125))
                                    .markdownMargin(top: 24, bottom: 16)
                                    .markdownTextStyle {
                                        FontWeight(.semibold)
                                        FontSize(.em(1.25))
                                    }
                                Divider()
                            }
                        }
                )
                .padding()
                .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: .init(lineWidth: 1))
                        .foregroundColor(Color(nsColor: .separatorColor))
                }
                .padding()
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

struct CustomCommandView_NoEditing_Preview: PreviewProvider {
    static var previews: some View {
        CustomCommandView(
            editingCommand: nil,
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


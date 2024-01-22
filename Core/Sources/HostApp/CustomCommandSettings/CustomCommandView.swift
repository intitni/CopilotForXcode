import ComposableArchitecture
import MarkdownUI
import PlusFeatureFlag
import Preferences
import SharedUIComponents
import SwiftUI
import Toast

extension List {
    @ViewBuilder
    func removeBackground() -> some View {
        if #available(macOS 13.0, *) {
            scrollContentBackground(.hidden)
                .listRowBackground(EmptyView())
        } else {
            background(Color.clear)
                .listRowBackground(EmptyView())
        }
    }
}

let customCommandStore = StoreOf<CustomCommandFeature>(
    initialState: .init(),
    reducer: CustomCommandFeature(
        settings: .init()
    )
)

struct CustomCommandView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.customCommands) var customCommands

        init(customCommands: AppStorage<[CustomCommand]>? = nil) {
            if let list = customCommands {
                _customCommands = list
            }
        }
    }

    var store: StoreOf<CustomCommandFeature>
    @StateObject var settings = Settings()
    @Environment(\.toast) var toast

    var body: some View {
        HStack(spacing: 0) {
            leftPane
            Divider()
            rightPane
        }
    }

    @ViewBuilder
    var leftPane: some View {
        List {
            ForEach(settings.customCommands, id: \.commandId) { command in
                CommandButton(store: store, command: command)
            }
            .onMove(perform: { indices, newOffset in
                settings.customCommands.move(fromOffsets: indices, toOffset: newOffset)
            })
            .modify { view in
                if #available(macOS 13.0, *) {
                    view.listRowSeparator(.hidden).listSectionSeparator(.hidden)
                } else {
                    view
                }
            }
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
                store.send(.createNewCommand)
            }) {
                if isFeatureAvailable(\.unlimitedCustomCommands) {
                    Text(Image(systemName: "plus.circle.fill")) + Text(" New Command")
                } else {
                    Text(Image(systemName: "plus.circle.fill")) +
                        Text(" New Command (\(settings.customCommands.count)/10)")
                }
            }
            .buttonStyle(.plain)
            .padding()
            .contextMenu {
                Button("Import") {
                    store.send(.importCommandClicked)
                }
            }
        }
        .onDrop(of: [.json], delegate: FileDropDelegate(store: store, toast: toast))
    }

    struct FileDropDelegate: DropDelegate {
        let store: StoreOf<CustomCommandFeature>
        let toast: (String, ToastType) -> Void
        func performDrop(info: DropInfo) -> Bool {
            let jsonFiles = info.itemProviders(for: [.json])
            for file in jsonFiles {
                file.loadInPlaceFileRepresentation(forTypeIdentifier: "public.json") { url, _, error in
                    Task { @MainActor in
                        if let url {
                            store.send(.importCommand(at: url))
                        } else if let error {
                            toast(error.localizedDescription, .error)
                        }
                    }
                }
            }

            return !jsonFiles.isEmpty
        }
    }

    struct CommandButton: View {
        let store: StoreOf<CustomCommandFeature>
        let command: CustomCommand

        var body: some View {
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
                        case .singleRoundDialog:
                            Text("Single Round Dialog")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    store.send(.editCommand(command))
                }
            }
            .padding(4)
            .background {
                WithViewStore(store, observe: { $0.editCustomCommand?.commandId }) { viewStore in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            viewStore.state == command.id
                                ? Color.primary.opacity(0.05)
                                : Color.clear
                        )
                }
            }
            .contextMenu {
                Button("Remove") {
                    store.send(.deleteCommand(command))
                }

                Button("Export") {
                    store.send(.exportCommand(command))
                }
            }
        }
    }

    @ViewBuilder
    var rightPane: some View {
        IfLetStore(store.scope(
            state: \.editCustomCommand,
            action: CustomCommandFeature.Action.editCustomCommand
        )) { store in
            EditCustomCommandView(store: store)
        } else: {
            VStack {
                SubSection(title: Text("Send Message")) {
                    Text(
                        "This command sends a message to the active chat tab. You can provide additional context through the \"Extra System Prompt\" as well."
                    )
                }
                SubSection(title: Text("Prompt to Code")) {
                    Text(
                        "This command opens the prompt-to-code panel and executes the provided requirements on the selected code. You can provide additional context through the \"Extra Context\" as well."
                    )
                }
                SubSection(title: Text("Custom Chat")) {
                    Text(
                        "This command will overwrite the system prompt to let the bot behave differently."
                    )
                }
                SubSection(title: Text("Single Round Dialog")) {
                    Text(
                        "This command allows you to send a message to a temporary chat without opening the chat panel. It is particularly useful for one-time commands, such as running a terminal command with `/run`. For example, you can set the prompt to `/run open .` to open the project in Finder."
                    )
                }
            }
            .padding()
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
        let settings = CustomCommandView.Settings(customCommands: .init(wrappedValue: [
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

        return CustomCommandView(
            store: .init(
                initialState: .init(
                    editCustomCommand: .init(.init(.init(
                        commandId: "1",
                        name: "Explain Code",
                        feature: .chatWithSelection(
                            extraSystemPrompt: nil,
                            prompt: "Hello",
                            useExtraSystemPrompt: false
                        )
                    )))
                ),
                reducer: CustomCommandFeature(settings: settings)
            ),
            settings: settings
        )
    }
}

struct CustomCommandView_NoEditing_Preview: PreviewProvider {
    static var previews: some View {
        let settings = CustomCommandView.Settings(customCommands: .init(wrappedValue: [
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

        return CustomCommandView(
            store: .init(
                initialState: .init(
                    editCustomCommand: nil
                ),
                reducer: CustomCommandFeature(settings: settings)
            ),
            settings: settings
        )
    }
}


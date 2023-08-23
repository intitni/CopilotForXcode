import MarkdownUI
import SharedUIComponents
import SwiftUI

struct PromptToCodePanel: View {
    @ObservedObject var provider: PromptToCodeProvider

    var body: some View {
        VStack(spacing: 0) {
            TopBar(provider: provider)

            Content(provider: provider)
                .overlay(alignment: .bottom) {
                    ActionBar(provider: provider)
                        .padding(.bottom, 8)
                }

            Divider()

            Toolbar(provider: provider)
        }
        .background(.ultraThickMaterial)
        .xcodeStyleFrame()
    }
}

extension PromptToCodePanel {
    struct TopBar: View {
        @ObservedObject var provider: PromptToCodeProvider

        var body: some View {
            HStack {
                Button(action: {
                    provider.toggleAttachOrDetachToCode()
                }) {
                    let attachedToRange = provider.attachedToRange
                    let isAttached = attachedToRange != nil
                    let color: Color = isAttached ? .indigo : .secondary.opacity(0.6)
                    HStack(spacing: 4) {
                        Image(systemName: isAttached ? "bandage" : "character.cursor.ibeam")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .frame(width: 20, height: 20, alignment: .center)
                            .foregroundColor(.white)
                            .background(
                                color,
                                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                            )

                        Text(attachedToRange?.description ?? "text cursor")
                            .foregroundColor(.primary)
                    }
                    .padding(2)
                    .padding(.trailing, 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(
                                color,
                                lineWidth: 1
                            )
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(color.opacity(0.2))
                    }
                    .padding(2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("j", modifiers: [.command])

                Spacer()

                if !provider.code.isEmpty {
                    CopyButton {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(provider.code, forType: .string)
                    }
                }
            }
            .padding(2)
        }
    }

    struct ActionBar: View {
        @ObservedObject var provider: PromptToCodeProvider

        var body: some View {
            HStack {
                if provider.isResponding {
                    Button(action: {
                        provider.stopResponding()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .padding(8)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }

                let isRespondingButCodeIsReady = provider.isResponding
                    && !provider.code.isEmpty
                    && !provider.description.isEmpty

                if !provider.isResponding || isRespondingButCodeIsReady {
                    HStack {
                        Toggle(
                            "Continuous Mode",
                            isOn: .init(
                                get: { provider.isContinuous },
                                set: { _ in provider.toggleContinuous() }
                            )
                        )
                        .toggleStyle(.checkbox)

                        Button(action: {
                            provider.cancel()
                        }) {
                            Text("Cancel")
                        }
                        .buttonStyle(CommandButtonStyle(color: .gray))
                        .keyboardShortcut("w", modifiers: [.command])

                        if !provider.code.isEmpty {
                            Button(action: {
                                provider.acceptSuggestion()
                            }) {
                                Text("Accept(⌘ + ⏎)")
                            }
                            .buttonStyle(CommandButtonStyle(color: .indigo))
                            .keyboardShortcut(KeyEquivalent.return, modifiers: [.command])
                        }
                    }
                    .padding(8)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }
                }
            }
        }
    }

    struct Content: View {
        @ObservedObject var provider: PromptToCodeProvider
        @Environment(\.colorScheme) var colorScheme
        @AppStorage(\.suggestionCodeFontSize) var fontSize

        var body: some View {
            CustomScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    if !provider.errorMessage.isEmpty {
                        Text(provider.errorMessage)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Color.red,
                                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            }
                            .scaleEffect(x: 1, y: -1, anchor: .center)
                    }

                    if !provider.description.isEmpty {
                        Markdown(provider.description)
                            .textSelection(.enabled)
                            .markdownTheme(.gitHub.text {
                                BackgroundColor(Color.clear)
                            })
                            .padding()
                            .frame(maxWidth: .infinity)
                            .scaleEffect(x: 1, y: -1, anchor: .center)
                    }

                    if provider.code.isEmpty {
                        Text(
                            provider.isResponding
                                ? "Thinking..."
                                : "Enter your requirement to generate code."
                        )
                        .foregroundColor(.secondary)
                        .padding()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: 1, y: -1, anchor: .center)
                    } else {
                        CodeBlock(
                            code: provider.code,
                            language: provider.language,
                            startLineIndex: provider.startLineIndex,
                            colorScheme: colorScheme,
                            firstLinePrecedingSpaceCount: provider.startLineColumn,
                            fontSize: fontSize
                        )
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: 1, y: -1, anchor: .center)
                    }

                    if let name = provider.name {
                        Text(name)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 12)
                            .scaleEffect(x: 1, y: -1, anchor: .center)
                    }
                }
            }
            .scaleEffect(x: 1, y: -1, anchor: .center)
        }
    }

    struct Toolbar: View {
        @ObservedObject var provider: PromptToCodeProvider
        @FocusState var isInputAreaFocused: Bool

        var body: some View {
            HStack {
                Button(action: {
                    provider.revert()
                }) {
                    Group {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .padding(6)
                    .background {
                        Circle().fill(Color(nsColor: .controlBackgroundColor))
                    }
                    .overlay {
                        Circle()
                            .stroke(Color(nsColor: .controlColor), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(provider.isResponding || !provider.canRevert)

                HStack(spacing: 0) {
                    ZStack(alignment: .center) {
                        // a hack to support dynamic height of TextEditor
                        Text(provider.requirement.isEmpty ? "Hi" : provider.requirement).opacity(0)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, maxHeight: 400)
                            .padding(.top, 1)
                            .padding(.bottom, 2)
                            .padding(.horizontal, 4)

                        CustomTextEditor(
                            text: $provider.requirement,
                            font: .systemFont(ofSize: 14),
                            onSubmit: { provider.sendRequirement() }
                        )
                        .padding(.top, 1)
                        .padding(.bottom, -1)
                    }
                    .focused($isInputAreaFocused)
                    .padding(8)
                    .fixedSize(horizontal: false, vertical: true)

                    Button(action: {
                        provider.sendRequirement()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(provider.isResponding)
                    .keyboardShortcut(KeyEquivalent.return, modifiers: [])
                }
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .controlColor), lineWidth: 1)
                }
                .background {
                    Button(action: {
                        provider.requirement += "\n"
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut(KeyEquivalent.return, modifiers: [.shift])
                }
            }
            .onAppear {
                isInputAreaFocused = true
            }
            .padding(8)
            .background(.ultraThickMaterial)
        }
    }
}

// MARK: - Previews

struct PromptToCodePanel_Preview: PreviewProvider {
    static var previews: some View {
        PromptToCodePanel(provider: PromptToCodeProvider(
            code: """
            ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in
                Text(viewModel.suggestion[index])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            """,
            language: "swift",
            description: "Hello world",
            isResponding: false,
            attachedToRange: .init(
                start: .init(line: 8, character: 0),
                end: .init(line: 12, character: 2)
            ),
            name: "Generate Code"
        ))
        .frame(width: 450, height: 400)
    }
}

struct PromptToCodePanel_Error_Detached_Preview: PreviewProvider {
    static var previews: some View {
        PromptToCodePanel(provider: PromptToCodeProvider(
            code: """
            ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in
                Text(viewModel.suggestion[index])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            """,
            language: "swift",
            description: "Hello world",
            isResponding: false,
            attachedToRange: nil,
            errorMessage: "Error",
            name: "Generate Code"
        ))
        .frame(width: 450, height: 400)
    }
}


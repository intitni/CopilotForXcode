import ComposableArchitecture
import MarkdownUI
import SharedUIComponents
import SuggestionModel
import SwiftUI

struct PromptToCodePanel: View {
    let store: StoreOf<PromptToCode>

    var body: some View {
        VStack(spacing: 0) {
            TopBar(store: store)

            Content(store: store)
                .overlay(alignment: .bottom) {
                    ActionBar(store: store)
                        .padding(.bottom, 8)
                }

            Divider()

            Toolbar(store: store)
        }
        .background(.ultraThickMaterial)
        .xcodeStyleFrame()
    }
}

extension PromptToCodePanel {
    struct TopBar: View {
        let store: StoreOf<PromptToCode>

        struct AttachButtonState: Equatable {
            var isAttachedToSelectionRange: Bool
            var selectionRange: CursorRange?
        }

        var body: some View {
            HStack {
                Button(action: {
                    withAnimation(.linear(duration: 0.1)) {
                        store.send(.selectionRangeToggleTapped)
                    }
                }) {
                    WithViewStore(
                        store,
                        observe: { AttachButtonState(
                            isAttachedToSelectionRange: $0.isAttachedToSelectionRange,
                            selectionRange: $0.selectionRange
                        ) }
                    ) { viewStore in
                        let isAttached = viewStore.state.isAttachedToSelectionRange
                        let color: Color = isAttached ? .indigo : .secondary.opacity(0.6)
                        HStack(spacing: 4) {
                            Image(
                                systemName: isAttached ? "bandage" : "character.cursor.ibeam"
                            )
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .frame(width: 20, height: 20, alignment: .center)
                            .foregroundColor(.white)
                            .background(
                                color,
                                in: RoundedRectangle(
                                    cornerRadius: 4,
                                    style: .continuous
                                )
                            )

                            let text: String = {
                                if isAttached, let range = viewStore.state.selectionRange {
                                    return range.description
                                }
                                return "text cursor"
                            }()
                            Text(text).foregroundColor(.primary)
                        }
                        .padding(2)
                        .padding(.trailing, 4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(color, lineWidth: 1)
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(color.opacity(0.2))
                        }
                        .padding(2)
                    }
                }
                .keyboardShortcut("j", modifiers: [.command])
                .buttonStyle(.plain)

                Spacer()

                WithViewStore(store, observe: { $0.code }) { viewStore in
                    if !viewStore.state.isEmpty {
                        CopyButton {
                            viewStore.send(.copyCodeButtonTapped)
                        }
                    }
                }
            }
            .padding(2)
        }
    }

    struct ActionBar: View {
        let store: StoreOf<PromptToCode>

        struct ActionState: Equatable {
            var isResponding: Bool
            var isCodeEmpty: Bool
            var isDescriptionEmpty: Bool
            @BindingViewState var isContinuous: Bool
            var isRespondingButCodeIsReady: Bool {
                isResponding
                    && !isCodeEmpty
                    && !isDescriptionEmpty
            }
        }

        var body: some View {
            HStack {
                WithViewStore(store, observe: { $0.isResponding }) { viewStore in
                    if viewStore.state {
                        Button(action: {
                            viewStore.send(.stopRespondingButtonTapped)
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
                }

                WithViewStore(store, observe: {
                    ActionState(
                        isResponding: $0.isResponding,
                        isCodeEmpty: $0.code.isEmpty,
                        isDescriptionEmpty: $0.description.isEmpty,
                        isContinuous: $0.$isContinuous
                    )
                }) { viewStore in
                    if !viewStore.state.isResponding || viewStore.state.isRespondingButCodeIsReady {
                        HStack {
                            Toggle("Continuous Mode", isOn: viewStore.$isContinuous)
                                .toggleStyle(.checkbox)

                            Button(action: {
                                viewStore.send(.cancelButtonTapped)
                            }) {
                                Text("Cancel")
                            }
                            .buttonStyle(CommandButtonStyle(color: .gray))
                            .keyboardShortcut("w", modifiers: [.command])

                            if !viewStore.state.isCodeEmpty {
                                Button(action: {
                                    viewStore.send(.acceptButtonTapped)
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
    }

    struct Content: View {
        let store: StoreOf<PromptToCode>
        @Environment(\.colorScheme) var colorScheme
        @AppStorage(\.suggestionCodeFontSize) var fontSize

        struct CodeContent: Equatable {
            var code: String
            var language: String
            var startLineIndex: Int
            var firstLinePrecedingSpaceCount: Int
            var isResponding: Bool
        }

        var body: some View {
            CustomScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    WithViewStore(store, observe: { $0.error }) { viewStore in
                        if let errorMessage = viewStore.state, !errorMessage.isEmpty {
                            Text(errorMessage)
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
                    }

                    WithViewStore(store, observe: { $0.description }) { viewStore in
                        if !viewStore.state.isEmpty {
                            Markdown(viewStore.state)
                                .textSelection(.enabled)
                                .markdownTheme(.gitHub.text {
                                    BackgroundColor(Color.clear)
                                })
                                .padding()
                                .frame(maxWidth: .infinity)
                                .scaleEffect(x: 1, y: -1, anchor: .center)
                        }
                    }

                    WithViewStore(store, observe: {
                        CodeContent(
                            code: $0.code,
                            language: $0.language.rawValue,
                            startLineIndex: $0.selectionRange?.start.line ?? 0,
                            firstLinePrecedingSpaceCount: $0.selectionRange?.start
                                .character ?? 0,
                            isResponding: $0.isResponding
                        )
                    }) { viewStore in
                        if viewStore.state.code.isEmpty {
                            Text(
                                viewStore.state.isResponding
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
                                code: viewStore.state.code,
                                language: viewStore.state.language,
                                startLineIndex: viewStore.state.startLineIndex,
                                colorScheme: colorScheme,
                                firstLinePrecedingSpaceCount: viewStore.state
                                    .firstLinePrecedingSpaceCount,
                                fontSize: fontSize
                            )
                            .frame(maxWidth: .infinity)
                            .scaleEffect(x: 1, y: -1, anchor: .center)
                        }
                    }
                }
            }
            .scaleEffect(x: 1, y: -1, anchor: .center)
        }
    }

    struct Toolbar: View {
        let store: StoreOf<PromptToCode>
        @FocusState var isInputAreaFocused: Bool

        struct RevertButtonState: Equatable {
            var isResponding: Bool
            var canRevert: Bool
        }

        struct InputFieldState: Equatable {
            @BindingViewState var prompt: String
            var isResponding: Bool
        }

        var body: some View {
            HStack {
                revertButton

                HStack(spacing: 0) {
                    inputField
                    sendButton
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
                    Button(action: { store.send(.appendNewLineToPromptButtonTapped) }) {
                        EmptyView()
                    }
                    .keyboardShortcut(KeyEquivalent.return, modifiers: [.shift])
                }
                .background {
                    Button(action: { isInputAreaFocused = true }) {
                        EmptyView()
                    }
                    .keyboardShortcut("l", modifiers: [.command])
                }
            }
            .onAppear {
                isInputAreaFocused = true
            }
            .padding(8)
            .background(.ultraThickMaterial)
        }

        var revertButton: some View {
            WithViewStore(store, observe: {
                RevertButtonState(isResponding: $0.isResponding, canRevert: $0.canRevert)
            }) { viewStore in
                Button(action: {
                    viewStore.send(.revertButtonTapped)
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
                .disabled(viewStore.state.isResponding || !viewStore.state.canRevert)
            }
        }

        var inputField: some View {
            WithViewStore(
                store,
                observe: { InputFieldState(prompt: $0.$prompt, isResponding: $0.isResponding) }
            ) { viewStore in
                ZStack(alignment: .center) {
                    // a hack to support dynamic height of TextEditor
                    Text(viewStore.state.prompt.isEmpty ? "Hi" : viewStore.state.prompt)
                        .opacity(0)
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, maxHeight: 400)
                        .padding(.top, 1)
                        .padding(.bottom, 2)
                        .padding(.horizontal, 4)

                    CustomTextEditor(
                        text: viewStore.$prompt,
                        font: .systemFont(ofSize: 14),
                        isEditable: !viewStore.state.isResponding,
                        onSubmit: { viewStore.send(.modifyCodeButtonTapped) }
                    )
                    .padding(.top, 1)
                    .padding(.bottom, -1)
                    .opacity(viewStore.state.isResponding ? 0.5 : 1)
                    .disabled(viewStore.state.isResponding)
                }
            }
            .focused($isInputAreaFocused)
            .padding(8)
            .fixedSize(horizontal: false, vertical: true)
        }

        var sendButton: some View {
            WithViewStore(store, observe: { $0.isResponding }) { viewStore in
                Button(action: {
                    viewStore.send(.modifyCodeButtonTapped)
                }) {
                    Image(systemName: "paperplane.fill")
                        .padding(8)
                }
                .buttonStyle(.plain)
                .disabled(viewStore.state)
                .keyboardShortcut(KeyEquivalent.return, modifiers: [])
            }
        }
    }
}

// MARK: - Previews

struct PromptToCodePanel_Preview: PreviewProvider {
    static var previews: some View {
        PromptToCodePanel(store: .init(initialState: .init(
            code: """
            ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in
                Text(viewModel.suggestion[index])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            """,
            prompt: "",
            language: .builtIn(.swift),
            indentSize: 4,
            usesTabsForIndentation: false,
            projectRootURL: URL(fileURLWithPath: ""),
            documentURL: URL(fileURLWithPath: ""),
            allCode: "",
            commandName: "Generate Code",
            description: "Hello world",
            isResponding: false,
            isAttachedToSelectionRange: true,
            selectionRange: .init(
                start: .init(line: 8, character: 0),
                end: .init(line: 12, character: 2)
            )
        ), reducer: PromptToCode()))
            .frame(width: 450, height: 400)
    }
}

struct PromptToCodePanel_Error_Detached_Preview: PreviewProvider {
    static var previews: some View {
        PromptToCodePanel(store: .init(initialState: .init(
            code: """
            ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in
                Text(viewModel.suggestion[index])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            """,
            prompt: "",
            language: .builtIn(.swift),
            indentSize: 4,
            usesTabsForIndentation: false,
            projectRootURL: URL(fileURLWithPath: ""),
            documentURL: URL(fileURLWithPath: ""),
            allCode: "",
            commandName: "Generate Code",
            description: "Hello world",
            isResponding: false,
            isAttachedToSelectionRange: false,
            error: "Error",
            selectionRange: .init(
                start: .init(line: 8, character: 0),
                end: .init(line: 12, character: 2)
            )
        ), reducer: PromptToCode()))
            .frame(width: 450, height: 400)
    }
}


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
            var attachedToFilename: String
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
                            attachedToFilename: $0.filename,
                            isAttachedToSelectionRange: $0.isAttachedToSelectionRange,
                            selectionRange: $0.selectionRange
                        ) }
                    ) { viewStore in
                        let isAttached = viewStore.state.isAttachedToSelectionRange
                        let color: Color = isAttached ? .accentColor : .secondary.opacity(0.6)
                        HStack(spacing: 4) {
                            Image(
                                systemName: isAttached ? "link" : "character.cursor.ibeam"
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

                            if isAttached {
                                HStack(spacing: 4) {
                                    Text(viewStore.state.attachedToFilename)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    if let range = viewStore.state.selectionRange {
                                        Text(range.description)
                                    }
                                }.foregroundColor(.primary)
                            } else {
                                Text("current selection").foregroundColor(.secondary)
                            }
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
                                .buttonStyle(CommandButtonStyle(color: .accentColor))
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
        @AppStorage(\.promptToCodeCodeFont) var codeFont
        @AppStorage(\.hideCommonPrecedingSpacesInPromptToCode) var hideCommonPrecedingSpaces
        @AppStorage(\.syncPromptToCodeHighlightTheme) var syncHighlightTheme
        @AppStorage(\.codeForegroundColorLight) var codeForegroundColorLight
        @AppStorage(\.codeForegroundColorDark) var codeForegroundColorDark
        @AppStorage(\.codeBackgroundColorLight) var codeBackgroundColorLight
        @AppStorage(\.codeBackgroundColorDark) var codeBackgroundColorDark
        @AppStorage(\.wrapCodeInPromptToCode) var wrapCode
        
        struct CodeContent: Equatable {
            var code: String
            var language: String
            var startLineIndex: Int
            var firstLinePrecedingSpaceCount: Int
            var isResponding: Bool
        }
        
        var codeForegroundColor: Color? {
            if syncHighlightTheme {
                if colorScheme == .light,
                   let color = codeForegroundColorLight.value?.swiftUIColor
                {
                    return color
                } else if let color = codeForegroundColorDark.value?.swiftUIColor {
                    return color
                }
            }
            return nil
        }
        
        var codeBackgroundColor: Color {
            if syncHighlightTheme {
                if colorScheme == .light,
                   let color = codeBackgroundColorLight.value?.swiftUIColor
                {
                    return color
                } else if let color = codeBackgroundColorDark.value?.swiftUIColor {
                    return color
                }
            }
            return Color.contentBackground
        }

        var body: some View {
            ScrollView {
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
                                    ForegroundColor(codeForegroundColor)
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
                            .foregroundColor(codeForegroundColor?.opacity(0.7) ?? .secondary)
                            .padding()
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(x: 1, y: -1, anchor: .center)
                        } else {
                            if wrapCode {
                                codeBlock(viewStore.state)
                            } else {
                                ScrollView(.horizontal) {
                                    codeBlock(viewStore.state)
                                }
                                .modify {
                                    if #available(macOS 13.0, *) {
                                        $0.scrollIndicators(.hidden)
                                    } else {
                                        $0
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .background(codeBackgroundColor)
            .scaleEffect(x: 1, y: -1, anchor: .center)
        }
        
        func codeBlock(_ state: CodeContent) -> some View {
            CodeBlock(
                code: state.code,
                language: state.language,
                startLineIndex: state.startLineIndex,
                scenario: "promptToCode",
                colorScheme: colorScheme,
                firstLinePrecedingSpaceCount: state.firstLinePrecedingSpaceCount,
                font: codeFont.value.nsFont,
                droppingLeadingSpaces: hideCommonPrecedingSpaces,
                proposedForegroundColor:codeForegroundColor
            )
            .frame(maxWidth: .infinity)
            .scaleEffect(x: 1, y: -1, anchor: .center)
        }
    }

    struct Toolbar: View {
        let store: StoreOf<PromptToCode>
        @FocusState var focusField: PromptToCode.State.FocusField?

        struct RevertButtonState: Equatable {
            var isResponding: Bool
            var canRevert: Bool
        }

        struct InputFieldState: Equatable {
            @BindingViewState var prompt: String
            @BindingViewState var focusField: PromptToCode.State.FocusField?
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
                    Button(action: { focusField = .textField }) {
                        EmptyView()
                    }
                    .keyboardShortcut("l", modifiers: [.command])
                }
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
                observe: {
                    InputFieldState(
                        prompt: $0.$prompt,
                        focusField: $0.$focusedField,
                        isResponding: $0.isResponding
                    )
                }
            ) { viewStore in
                AutoresizingCustomTextEditor(
                    text: viewStore.$prompt,
                    font: .systemFont(ofSize: 14),
                    isEditable: !viewStore.state.isResponding,
                    maxHeight: 400,
                    onSubmit: { viewStore.send(.modifyCodeButtonTapped) }
                )
                .opacity(viewStore.state.isResponding ? 0.5 : 1)
                .disabled(viewStore.state.isResponding)
                .focused($focusField, equals: .textField)
                .bind(viewStore.$focusField, to: $focusField)
            }
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
            projectRootURL: URL(fileURLWithPath: "path/to/file.txt"),
            documentURL: URL(fileURLWithPath: "path/to/file.txt"),
            allCode: "",
            allLines: [],
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

#Preview("Prompt to Code Panel Super Long File Name") {
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
        projectRootURL: URL(fileURLWithPath: "path/to/file.txt"),
        documentURL: URL(
            fileURLWithPath: "path/to/file-name-is-super-long-what-should-we-do-with-it-hah.txt"
        ),
        allCode: "",
        allLines: [],
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
            projectRootURL: URL(fileURLWithPath: "path/to/file.txt"),
            documentURL: URL(fileURLWithPath: "path/to/file.txt"),
            allCode: "",
            allLines: [],
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


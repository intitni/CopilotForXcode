import Cocoa
import ComposableArchitecture
import MarkdownUI
import PromptToCodeBasic
import PromptToCodeCustomization
import SharedUIComponents
import SuggestionBasic
import SwiftUI

struct PromptToCodePanelView: View {
    let store: StoreOf<PromptToCodePanel>

    var body: some View {
        WithPerceptionTracking {
            PromptToCodeCustomization.CustomizedUI(
                state: store.$promptToCodeState,
                isInputFieldFocused: .constant(true)
            ) { _ in
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
            }
            .background(.ultraThickMaterial)
            .xcodeStyleFrame()
        }
    }
}

extension PromptToCodePanelView {
    struct TopBar: View {
        let store: StoreOf<PromptToCodePanel>

        var body: some View {
            WithPerceptionTracking {
                VStack(spacing: 0) {
                    HStack {
                        SelectionRangeButton(store: store)
                        Spacer()
                    }
                    .padding(2)

                    Divider()

                    if let previousStep = store.promptToCodeState.history.last {
                        Button(action: {
                            store.send(.revertButtonTapped)
                        }, label: {
                            HStack(spacing: 4) {
                                Text(Image(systemName: "arrow.uturn.backward.circle.fill"))
                                    .foregroundStyle(.secondary)
                                Text(previousStep.instruction)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        })
                        .buttonStyle(.plain)
                        .disabled(store.promptToCodeState.isGenerating)
                        .padding(6)

                        Divider()
                    }
                }
                .animation(.linear(duration: 0.1), value: store.promptToCodeState.history.count)
            }
        }

        struct SelectionRangeButton: View {
            let store: StoreOf<PromptToCodePanel>
            var body: some View {
                WithPerceptionTracking {
                    Button(action: {
                        store.send(.selectionRangeToggleTapped, animation: .linear(duration: 0.1))
                    }) {
                        let attachedToFilename = store.filename
                        let isAttached = store.promptToCodeState.isAttachedToTarget
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
                                    Text(attachedToFilename)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }.foregroundColor(.primary)
                            } else {
                                Text("current selection").foregroundColor(.secondary)
                            }
                        }
                        .padding(2)
                        .padding(.trailing, 4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(color, lineWidth: 1)
                        }
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(color.opacity(0.2))
                        }
                        .padding(2)
                    }
                    .keyboardShortcut("j", modifiers: [.command])
                    .buttonStyle(.plain)
                }
            }
        }
    }

    struct ActionBar: View {
        let store: StoreOf<PromptToCodePanel>

        var body: some View {
            HStack {
                StopRespondingButton(store: store)
                ActionButtons(store: store)
            }
        }

        struct StopRespondingButton: View {
            let store: StoreOf<PromptToCodePanel>

            var body: some View {
                WithPerceptionTracking {
                    if store.promptToCodeState.isGenerating {
                        Button(action: {
                            store.send(.stopRespondingButtonTapped)
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
            }
        }

        struct ActionButtons: View {
            @Perception.Bindable var store: StoreOf<PromptToCodePanel>

            var body: some View {
                WithPerceptionTracking {
                    let isResponding = store.promptToCodeState.isGenerating
                    let isCodeEmpty = store.promptToCodeState.snippets
                        .allSatisfy(\.modifiedCode.isEmpty)
                    let isDescriptionEmpty = store.promptToCodeState.snippets
                        .allSatisfy(\.description.isEmpty)
                    var isRespondingButCodeIsReady: Bool {
                        isResponding
                            && !isCodeEmpty
                            && !isDescriptionEmpty
                    }
                    if !isResponding || isRespondingButCodeIsReady {
                        HStack {
                            Menu {
                                WithPerceptionTracking {
                                    Toggle(
                                        "Always accept and continue",
                                        isOn: $store.isContinuous
                                            .animation(.easeInOut(duration: 0.1))
                                    )
                                    .toggleStyle(.checkbox)
                                }
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                    .frame(maxHeight: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                store.send(.cancelButtonTapped)
                            }) {
                                Text("Cancel")
                            }
                            .buttonStyle(CommandButtonStyle(color: .gray))
                            .keyboardShortcut("w", modifiers: [.command])

                            if !isCodeEmpty {
                                AcceptButton(store: store)
                            }
                        }
                        .fixedSize()
                        .padding(8)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        }
                        .animation(
                            .easeInOut(duration: 0.1),
                            value: store.promptToCodeState.snippets
                        )
                    }
                }
            }
        }

        struct AcceptButton: View {
            let store: StoreOf<PromptToCodePanel>
            @Environment(\.modifierFlags) var modifierFlags

            struct TheButtonStyle: ButtonStyle {
                func makeBody(configuration: Configuration) -> some View {
                    configuration.label
                        .background(
                            Rectangle()
                                .fill(Color.accentColor.opacity(configuration.isPressed ? 0.8 : 1))
                        )
                }
            }

            var body: some View {
                WithPerceptionTracking {
                    let defaultModeIsContinuous = store.isContinuous
                    let isAttached = store.promptToCodeState.isAttachedToTarget

                    HStack(spacing: 0) {
                        Button(action: {
                            switch (
                                modifierFlags.contains(.option),
                                defaultModeIsContinuous
                            ) {
                            case (true, true):
                                store.send(.acceptButtonTapped)
                            case (false, true):
                                store.send(.acceptAndContinueButtonTapped)
                            case (true, false):
                                store.send(.acceptAndContinueButtonTapped)
                            case (false, false):
                                store.send(.acceptButtonTapped)
                            }
                        }) {
                            Group {
                                switch (
                                    isAttached,
                                    modifierFlags.contains(.option),
                                    defaultModeIsContinuous
                                ) {
                                case (true, true, true):
                                    Text("Accept(⌥ + ⌘ + ⏎)")
                                case (true, false, true):
                                    Text("Accept and Continue(⌘ + ⏎)")
                                case (true, true, false):
                                    Text("Accept and Continue(⌥ + ⌘ + ⏎)")
                                case (true, false, false):
                                    Text("Accept(⌘ + ⏎)")
                                case (false, true, true):
                                    Text("Replace(⌥ + ⌘ + ⏎)")
                                case (false, false, true):
                                    Text("Replace and Continue(⌘ + ⏎)")
                                case (false, true, false):
                                    Text("Replace and Continue(⌥ + ⌘ + ⏎)")
                                case (false, false, false):
                                    Text("Replace(⌘ + ⏎)")
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.leading, 8)
                            .padding(.trailing, 4)
                        }
                        .buttonStyle(TheButtonStyle())
                        .keyboardShortcut(
                            KeyEquivalent.return,
                            modifiers: modifierFlags
                                .contains(.option) ? [.command, .option] : [.command]
                        )

                        Divider()

                        Menu {
                            WithPerceptionTracking {
                                if defaultModeIsContinuous {
                                    Button(action: {
                                        store.send(.acceptButtonTapped)
                                    }) {
                                        Text("Accept(⌥ + ⌘ + ⏎)")
                                    }
                                } else {
                                    Button(action: {
                                        store.send(.acceptAndContinueButtonTapped)
                                    }) {
                                        Text("Accept and Continue(⌥ + ⌘ + ⏎)")
                                    }
                                }
                            }
                        } label: {
                            Text(Image(systemName: "chevron.down"))
                                .font(.footnote.weight(.bold))
                                .scaleEffect(0.8)
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(maxHeight: .infinity)
                                .padding(.leading, 1)
                                .padding(.trailing, 2)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .fixedSize()

                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
                    }
                }
            }
        }
    }

    struct Content: View {
        let store: StoreOf<PromptToCodePanel>

        @Environment(\.colorScheme) var colorScheme
        @AppStorage(\.syncPromptToCodeHighlightTheme) var syncHighlightTheme
        @AppStorage(\.codeForegroundColorLight) var codeForegroundColorLight
        @AppStorage(\.codeForegroundColorDark) var codeForegroundColorDark
        @AppStorage(\.codeBackgroundColorLight) var codeBackgroundColorLight
        @AppStorage(\.codeBackgroundColorDark) var codeBackgroundColorDark

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
            WithPerceptionTracking {
                ScrollView {
                    WithPerceptionTracking {
                        VStack(spacing: 0) {
                            Spacer(minLength: 56)

                            VStack(spacing: 0) {
                                let language = store.promptToCodeState.source.language
                                let isAttached = store.promptToCodeState.isAttachedToTarget
                                let lastId = store.promptToCodeState.snippets.last?.id
                                let isGenerating = store.promptToCodeState.isGenerating
                                ForEach(store.scope(
                                    state: \.snippetPanels,
                                    action: \.snippetPanel
                                )) { snippetStore in
                                    WithPerceptionTracking {
                                        if snippetStore.id != lastId {
                                            Divider()
                                        }

                                        SnippetPanelView(
                                            store: snippetStore,
                                            language: language,
                                            codeForegroundColor: codeForegroundColor ?? .primary,
                                            codeBackgroundColor: codeBackgroundColor,
                                            isAttached: isAttached,
                                            isGenerating: isGenerating
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .background(codeBackgroundColor)
                .scaleEffect(x: 1, y: -1, anchor: .center)
            }
        }

        struct SnippetPanelView: View {
            let store: StoreOf<PromptToCodeSnippetPanel>
            let language: CodeLanguage
            let codeForegroundColor: Color
            let codeBackgroundColor: Color
            let isAttached: Bool
            let isGenerating: Bool

            var body: some View {
                WithPerceptionTracking {
                    VStack(spacing: 0) {
                        ErrorMessage(store: store)
                        DescriptionContent(store: store, codeForegroundColor: codeForegroundColor)
                        CodeContent(
                            store: store,
                            language: language,
                            isGenerating: isGenerating,
                            codeForegroundColor: codeForegroundColor
                        )
                        SnippetTitleBar(
                            store: store,
                            language: language,
                            codeForegroundColor: codeForegroundColor,
                            isAttached: isAttached
                        )
                    }
                }
            }
        }

        struct SnippetTitleBar: View {
            let store: StoreOf<PromptToCodeSnippetPanel>
            let language: CodeLanguage
            let codeForegroundColor: Color
            let isAttached: Bool
            var body: some View {
                WithPerceptionTracking {
                    HStack {
                        Text(language.rawValue)
                            .foregroundStyle(codeForegroundColor)
                            .font(.callout.bold())
                            .lineLimit(1)
                        if isAttached {
                            Text(String(describing: store.snippet.attachedRange))
                                .foregroundStyle(codeForegroundColor.opacity(0.5))
                                .font(.callout)
                        }
                        Spacer()
                        CopyCodeButton(store: store)
                    }
                    .padding(.leading, 8)
                    .scaleEffect(x: 1, y: -1, anchor: .center)
                }
            }
        }

        struct CopyCodeButton: View {
            let store: StoreOf<PromptToCodeSnippetPanel>
            var body: some View {
                WithPerceptionTracking {
                    if !store.snippet.modifiedCode.isEmpty {
                        CopyButton {
                            store.send(.copyCodeButtonTapped)
                        }
                    }
                }
            }
        }

        struct ErrorMessage: View {
            let store: StoreOf<PromptToCodeSnippetPanel>

            var body: some View {
                WithPerceptionTracking {
                    if let errorMessage = store.snippet.error, !errorMessage.isEmpty {
                        (
                            Text(Image(systemName: "exclamationmark.triangle.fill")) +
                                Text(" ") +
                                Text(errorMessage)
                        )
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .scaleEffect(x: 1, y: -1, anchor: .center)
                    }
                }
            }
        }

        struct DescriptionContent: View {
            let store: StoreOf<PromptToCodeSnippetPanel>
            let codeForegroundColor: Color?

            var body: some View {
                WithPerceptionTracking {
                    if !store.snippet.description.isEmpty {
                        Markdown(store.snippet.description)
                            .textSelection(.enabled)
                            .markdownTheme(.gitHub.text {
                                BackgroundColor(Color.clear)
                                ForegroundColor(codeForegroundColor)
                            })
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(x: 1, y: -1, anchor: .center)
                    }
                }
            }
        }

        struct CodeContent: View {
            let store: StoreOf<PromptToCodeSnippetPanel>
            let language: CodeLanguage
            let isGenerating: Bool
            let codeForegroundColor: Color?

            @AppStorage(\.wrapCodeInPromptToCode) var wrapCode

            var body: some View {
                WithPerceptionTracking {
                    if !store.snippet.modifiedCode.isEmpty {
                        let wrapCode = wrapCode ||
                            [CodeLanguage.plaintext, .builtIn(.markdown), .builtIn(.shellscript),
                             .builtIn(.tex)].contains(language)
                        if wrapCode {
                            CodeBlockInContent(
                                store: store,
                                language: language,
                                codeForegroundColor: codeForegroundColor
                            )
                        } else {
                            ScrollView(.horizontal) {
                                CodeBlockInContent(
                                    store: store,
                                    language: language,
                                    codeForegroundColor: codeForegroundColor
                                )
                            }
                            .modify {
                                if #available(macOS 13.0, *) {
                                    $0.scrollIndicators(.hidden)
                                } else {
                                    $0
                                }
                            }
                        }
                    } else {
                        if isGenerating {
                            Text("Thinking...")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .scaleEffect(x: 1, y: -1, anchor: .center)
                        } else {
                            Text("Enter your requirements to generate code.")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .scaleEffect(x: 1, y: -1, anchor: .center)
                        }
                    }
                }
            }

            struct CodeBlockInContent: View {
                let store: StoreOf<PromptToCodeSnippetPanel>
                let language: CodeLanguage
                let codeForegroundColor: Color?

                @Environment(\.colorScheme) var colorScheme
                @AppStorage(\.promptToCodeCodeFont) var codeFont
                @AppStorage(\.hideCommonPrecedingSpacesInPromptToCode) var hideCommonPrecedingSpaces

                var body: some View {
                    WithPerceptionTracking {
                        let startLineIndex = store.snippet.attachedRange.start.line
                        AsyncCodeBlock(
                            code: store.snippet.modifiedCode,
                            originalCode: store.snippet.originalCode,
                            language: language.rawValue,
                            startLineIndex: startLineIndex,
                            scenario: "promptToCode",
                            font: codeFont.value.nsFont,
                            droppingLeadingSpaces: hideCommonPrecedingSpaces,
                            proposedForegroundColor: codeForegroundColor,
                            ignoreWholeLineChangeInDiff: false
                        )
                        .frame(maxWidth: .infinity)

                        .scaleEffect(x: 1, y: -1, anchor: .center)
                    }
                }
            }
        }
    }

    struct Toolbar: View {
        let store: StoreOf<PromptToCodePanel>
        @FocusState var focusField: PromptToCodePanel.State.FocusField?

        var body: some View {
            HStack {
                HStack(spacing: 0) {
                    InputField(store: store, focusField: $focusField)
                    SendButton(store: store)
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

        struct InputField: View {
            @Perception.Bindable var store: StoreOf<PromptToCodePanel>
            var focusField: FocusState<PromptToCodePanel.State.FocusField?>.Binding

            var body: some View {
                WithPerceptionTracking {
                    AutoresizingCustomTextEditor(
                        text: $store.promptToCodeState.instruction,
                        font: .systemFont(ofSize: 14),
                        isEditable: !store.promptToCodeState.isGenerating,
                        maxHeight: 400,
                        onSubmit: { store.send(.modifyCodeButtonTapped) }
                    )
                    .opacity(store.promptToCodeState.isGenerating ? 0.5 : 1)
                    .disabled(store.promptToCodeState.isGenerating)
                    .focused(focusField, equals: PromptToCodePanel.State.FocusField.textField)
                    .bind($store.focusedField, to: focusField)
                }
                .padding(8)
                .fixedSize(horizontal: false, vertical: true)
            }
        }

        struct SendButton: View {
            let store: StoreOf<PromptToCodePanel>
            var body: some View {
                WithPerceptionTracking {
                    Button(action: {
                        store.send(.modifyCodeButtonTapped)
                    }) {
                        Image(systemName: "paperplane.fill")
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.promptToCodeState.isGenerating)
                    .keyboardShortcut(KeyEquivalent.return, modifiers: [])
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Multiple Snippets") {
    PromptToCodePanelView(store: .init(initialState: .init(
        promptToCodeState: Shared(PromptToCodeState(
            source: .init(
                language: CodeLanguage.builtIn(.swift),
                documentURL: URL(
                    fileURLWithPath: "path/to/file-name-is-super-long-what-should-we-do-with-it-hah-longer-longer.txt"
                ),
                projectRootURL: URL(fileURLWithPath: "path/to/file.txt"),
                content: "",
                lines: []
            ),
            history: [
                .init(snippets: [
                    .init(
                        startLineIndex: 8,
                        originalCode: "print(foo)",
                        modifiedCode: "print(bar)",
                        description: "",
                        error: "Error",
                        attachedRange: CursorRange(
                            start: .init(line: 8, character: 0),
                            end: .init(line: 12, character: 2)
                        )
                    ),
                ], instruction: "Previous instruction"),
            ],
            snippets: [
                .init(
                    startLineIndex: 8,
                    originalCode: "print(foo)",
                    modifiedCode: "print(bar)\nprint(baz)",
                    description: "",
                    error: "Error",
                    attachedRange: CursorRange(
                        start: .init(line: 8, character: 0),
                        end: .init(line: 12, character: 2)
                    )
                ),
                .init(
                    startLineIndex: 13,
                    originalCode: """
                        struct Foo {
                          var foo: Int
                        }
                    """,
                    modifiedCode: """
                        struct Bar {
                          var bar: String
                        }
                    """,
                    description: "Cool",
                    error: nil,
                    attachedRange: CursorRange(
                        start: .init(line: 13, character: 0),
                        end: .init(line: 12, character: 2)
                    )
                ),
            ],
            instruction: "",
            extraSystemPrompt: "",
            isAttachedToTarget: true
        )),
        indentSize: 4,
        usesTabsForIndentation: false,
        commandName: "Generate Code"
    ), reducer: { PromptToCodePanel() }))
        .frame(maxWidth: 450, maxHeight: Style.panelHeight)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 500, height: 500, alignment: .center)
}

#Preview("Detached With Long File Name") {
    PromptToCodePanelView(store: .init(initialState: .init(
        promptToCodeState: Shared(PromptToCodeState(
            source: .init(
                language: CodeLanguage.builtIn(.swift),
                documentURL: URL(
                    fileURLWithPath: "path/to/file-name-is-super-long-what-should-we-do-with-it-hah.txt"
                ),
                projectRootURL: URL(fileURLWithPath: "path/to/file.txt"),
                content: "",
                lines: []
            ),
            snippets: [
                .init(
                    startLineIndex: 8,
                    originalCode: "print(foo)",
                    modifiedCode: "print(bar)",
                    description: "",
                    error: "Error",
                    attachedRange: CursorRange(
                        start: .init(line: 8, character: 0),
                        end: .init(line: 12, character: 2)
                    )
                ),
                .init(
                    startLineIndex: 13,
                    originalCode: """
                      struct Bar {
                        var foo: Int
                      }
                    """,
                    modifiedCode: """
                        struct Bar {
                          var foo: String
                        }
                    """,
                    description: "Cool",
                    error: nil,
                    attachedRange: CursorRange(
                        start: .init(line: 13, character: 0),
                        end: .init(line: 12, character: 2)
                    )
                ),
            ],
            instruction: "",
            extraSystemPrompt: "",
            isAttachedToTarget: false
        )),
        indentSize: 4,
        usesTabsForIndentation: false,
        commandName: "Generate Code"
    ), reducer: { PromptToCodePanel() }))
        .frame(maxWidth: 450, maxHeight: Style.panelHeight)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 500, height: 500, alignment: .center)
}


import ComposableArchitecture
import MarkdownUI
import SharedUIComponents
import SuggestionModel
import SwiftUI

struct PromptToCodePanel: View {
    let store: StoreOf<PromptToCode>

    var body: some View {
        WithPerceptionTracking {
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
}

extension PromptToCodePanel {
    struct TopBar: View {
        let store: StoreOf<PromptToCode>

        var body: some View {
            HStack {
                SelectionRangeButton(store: store)
                Spacer()
                CopyCodeButton(store: store)
            }
            .padding(2)
        }

        struct SelectionRangeButton: View {
            let store: StoreOf<PromptToCode>
            var body: some View {
                WithPerceptionTracking {
                    Button(action: {
                        store.send(.selectionRangeToggleTapped, animation: .linear(duration: 0.1))
                    }) {
                        let attachedToFilename = store.filename
                        let isAttached = store.isAttachedToSelectionRange
                        let selectionRange = store.selectionRange
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
                                    if let range = selectionRange {
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
                    .keyboardShortcut("j", modifiers: [.command])
                    .buttonStyle(.plain)
                }
            }
        }

        struct CopyCodeButton: View {
            let store: StoreOf<PromptToCode>
            var body: some View {
                WithPerceptionTracking {
                    if !store.code.isEmpty {
                        CopyButton {
                            store.send(.copyCodeButtonTapped)
                        }
                    }
                }
            }
        }
    }

    struct ActionBar: View {
        let store: StoreOf<PromptToCode>

        var body: some View {
            HStack {
                StopRespondingButton(store: store)
                ActionButtons(store: store)
            }
        }

        struct StopRespondingButton: View {
            let store: StoreOf<PromptToCode>

            var body: some View {
                WithPerceptionTracking {
                    if store.isResponding {
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
            @Perception.Bindable var store: StoreOf<PromptToCode>

            var body: some View {
                WithPerceptionTracking {
                    let isResponding = store.isResponding
                    let isCodeEmpty = store.code.isEmpty
                    let isDescriptionEmpty = store.description.isEmpty
                    var isRespondingButCodeIsReady: Bool {
                        isResponding
                            && !isCodeEmpty
                            && !isDescriptionEmpty
                    }
                    if !isResponding || isRespondingButCodeIsReady {
                        HStack {
                            Toggle("Continuous Mode", isOn: $store.isContinuous)
                                .toggleStyle(.checkbox)

                            Button(action: {
                                store.send(.cancelButtonTapped)
                            }) {
                                Text("Cancel")
                            }
                            .buttonStyle(CommandButtonStyle(color: .gray))
                            .keyboardShortcut("w", modifiers: [.command])

                            if !isCodeEmpty {
                                Button(action: {
                                    store.send(.acceptButtonTapped)
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
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)
                        ErrorMessage(store: store)
                        DescriptionContent(store: store, codeForegroundColor: codeForegroundColor)
                        CodeContent(store: store, codeForegroundColor: codeForegroundColor)
                    }
                }
                .background(codeBackgroundColor)
                .scaleEffect(x: 1, y: -1, anchor: .center)
            }
        }

        struct ErrorMessage: View {
            let store: StoreOf<PromptToCode>

            var body: some View {
                WithPerceptionTracking {
                    if let errorMessage = store.error, !errorMessage.isEmpty {
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
            }
        }

        struct DescriptionContent: View {
            let store: StoreOf<PromptToCode>
            let codeForegroundColor: Color?

            var body: some View {
                WithPerceptionTracking {
                    if !store.description.isEmpty {
                        Markdown(store.description)
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
            }
        }

        struct CodeContent: View {
            let store: StoreOf<PromptToCode>
            let codeForegroundColor: Color?

            @AppStorage(\.wrapCodeInPromptToCode) var wrapCode

            var body: some View {
                WithPerceptionTracking {
                    if store.code.isEmpty {
                        Text(
                            store.isResponding
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
                            CodeBlockInContent(
                                store: store,
                                codeForegroundColor: codeForegroundColor
                            )
                        } else {
                            ScrollView(.horizontal) {
                                CodeBlockInContent(
                                    store: store,
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
                    }
                }
            }

            struct CodeBlockInContent: View {
                let store: StoreOf<PromptToCode>
                let codeForegroundColor: Color?

                @Environment(\.colorScheme) var colorScheme
                @AppStorage(\.promptToCodeCodeFont) var codeFont
                @AppStorage(\.hideCommonPrecedingSpacesInPromptToCode) var hideCommonPrecedingSpaces

                var body: some View {
                    WithPerceptionTracking {
                        let startLineIndex = store.selectionRange?.start.line ?? 0
                        let firstLinePrecedingSpaceCount = store.selectionRange?.start
                            .character ?? 0
                        CodeBlock(
                            code: store.code,
                            language: store.language.rawValue,
                            startLineIndex: startLineIndex,
                            scenario: "promptToCode",
                            colorScheme: colorScheme,
                            firstLinePrecedingSpaceCount: firstLinePrecedingSpaceCount,
                            font: codeFont.value.nsFont,
                            droppingLeadingSpaces: hideCommonPrecedingSpaces,
                            proposedForegroundColor: codeForegroundColor
                        )
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: 1, y: -1, anchor: .center)
                    }
                }
            }
        }
    }

    struct Toolbar: View {
        let store: StoreOf<PromptToCode>
        @FocusState var focusField: PromptToCode.State.FocusField?

        struct RevertButtonState: Equatable {
            var isResponding: Bool
            var canRevert: Bool
        }

        var body: some View {
            HStack {
                RevertButton(store: store)

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

        struct RevertButton: View {
            let store: StoreOf<PromptToCode>
            var body: some View {
                WithPerceptionTracking {
                    Button(action: {
                        store.send(.revertButtonTapped)
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
                    .disabled(store.isResponding || !store.canRevert)
                }
            }
        }

        struct InputField: View {
            @Perception.Bindable var store: StoreOf<PromptToCode>
            var focusField: FocusState<PromptToCode.State.FocusField?>.Binding

            var body: some View {
                WithPerceptionTracking {
                    AutoresizingCustomTextEditor(
                        text: $store.prompt,
                        font: .systemFont(ofSize: 14),
                        isEditable: !store.isResponding,
                        maxHeight: 400,
                        onSubmit: { store.send(.modifyCodeButtonTapped) }
                    )
                    .opacity(store.isResponding ? 0.5 : 1)
                    .disabled(store.isResponding)
                    .focused(focusField, equals: PromptToCode.State.FocusField.textField)
                    .bind($store.focusedField, to: focusField)
                }
                .padding(8)
                .fixedSize(horizontal: false, vertical: true)
            }
        }

        struct SendButton: View {
            let store: StoreOf<PromptToCode>
            var body: some View {
                WithPerceptionTracking {
                    Button(action: {
                        store.send(.modifyCodeButtonTapped)
                    }) {
                        Image(systemName: "paperplane.fill")
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isResponding)
                    .keyboardShortcut(KeyEquivalent.return, modifiers: [])
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Default") {
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
        allLines: [String](),
        commandName: "Generate Code",
        description: "Hello world",
        isResponding: false,
        isAttachedToSelectionRange: true,
        selectionRange: .init(
            start: .init(line: 8, character: 0),
            end: .init(line: 12, character: 2)
        )
    ), reducer: { PromptToCode() }))
        .frame(width: 450, height: 400)
}

#Preview("Super Long File Name") {
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
        allLines: [String](),
        commandName: "Generate Code",
        description: "Hello world",
        isResponding: false,
        isAttachedToSelectionRange: true,
        selectionRange: .init(
            start: .init(line: 8, character: 0),
            end: .init(line: 12, character: 2)
        )
    ), reducer: { PromptToCode() }))
        .frame(width: 450, height: 400)
}

#Preview("Error Detached") {
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
        allLines: [String](),
        commandName: "Generate Code",
        description: "Hello world",
        isResponding: false,
        isAttachedToSelectionRange: false,
        error: "Error",
        selectionRange: .init(
            start: .init(line: 8, character: 0),
            end: .init(line: 12, character: 2)
        )
    ), reducer: { PromptToCode() }))
        .frame(width: 450, height: 400)
}


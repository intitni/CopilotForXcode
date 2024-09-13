import Combine
import CommandHandler
import Dependencies
import Perception
import SharedUIComponents
import SuggestionBasic
import SwiftUI
import XcodeInspector

public struct PresentingCodeSuggestion: Equatable {
    public var code: String
    public var language: String
    public var startLineIndex: Int
    public var suggestionCount: Int
    public var currentSuggestionIndex: Int
    public var replacingRange: CursorRange
    public var replacingLines: [String]
    public var descriptions: [CodeSuggestion.Description]

    public init(
        code: String,
        language: String,
        startLineIndex: Int,
        suggestionCount: Int,
        currentSuggestionIndex: Int,
        replacingRange: CursorRange,
        replacingLines: [String],
        descriptions: [CodeSuggestion.Description] = []
    ) {
        self.code = code
        self.language = language
        self.startLineIndex = startLineIndex
        self.suggestionCount = suggestionCount
        self.currentSuggestionIndex = currentSuggestionIndex
        self.replacingRange = replacingRange
        self.replacingLines = replacingLines
        self.descriptions = descriptions
    }
}

struct CodeBlockSuggestionPanelView: View {
    let suggestion: PresentingCodeSuggestion
    @Environment(\.textCursorTracker) var textCursorTracker
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.suggestionCodeFont) var codeFont
    @AppStorage(\.suggestionDisplayCompactMode) var suggestionDisplayCompactMode
    @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode
    @AppStorage(\.hideCommonPrecedingSpacesInSuggestion) var hideCommonPrecedingSpaces
    @AppStorage(\.syncSuggestionHighlightTheme) var syncHighlightTheme
    @AppStorage(\.codeForegroundColorLight) var codeForegroundColorLight
    @AppStorage(\.codeForegroundColorDark) var codeForegroundColorDark
    @AppStorage(\.codeBackgroundColorLight) var codeBackgroundColorLight
    @AppStorage(\.codeBackgroundColorDark) var codeBackgroundColorDark

    struct ToolBar: View {
        @Dependency(\.commandHandler) var commandHandler
        let suggestion: PresentingCodeSuggestion

        var body: some View {
            WithPerceptionTracking {
                HStack {
                    Button(action: {
                        Task {
                            await commandHandler.presentPreviousSuggestion()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                    }.buttonStyle(.plain)

                    Text(
                        "\(suggestion.currentSuggestionIndex + 1) / \(suggestion.suggestionCount)"
                    )
                    .monospacedDigit()

                    Button(action: {
                        Task { await commandHandler.presentNextSuggestion() }
                    }) {
                        Image(systemName: "chevron.right")
                    }.buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        Task {
                            await commandHandler.dismissSuggestion()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Text("Dismiss").foregroundStyle(.tertiary).padding(.trailing, 4)
                    }.buttonStyle(.plain)

                    Button(action: {
                        Task {
                            await commandHandler.rejectSuggestions()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Text("Reject")
                    }.buttonStyle(CommandButtonStyle(color: .gray))

                    Button(action: {
                        Task {
                            await commandHandler.acceptSuggestion()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Text("Accept")
                    }.buttonStyle(CommandButtonStyle(color: .accentColor))
                }
                .padding(6)
                .foregroundColor(.secondary)
                .background(.regularMaterial)
            }
        }
    }

    struct CompactToolBar: View {
        @Dependency(\.commandHandler) var commandHandler
        let suggestion: PresentingCodeSuggestion

        var body: some View {
            WithPerceptionTracking {
                HStack {
                    Button(action: {
                        Task { await commandHandler.presentPreviousSuggestion() }
                    }) {
                        Image(systemName: "chevron.left")
                    }.buttonStyle(.plain)

                    Text(
                        "\(suggestion.currentSuggestionIndex + 1) / \(suggestion.suggestionCount)"
                    )
                    .monospacedDigit()

                    Button(action: {
                        Task { await commandHandler.presentNextSuggestion() }
                    }) {
                        Image(systemName: "chevron.right")
                    }.buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        Task {
                            await commandHandler.dismissSuggestion()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Image(systemName: "xmark")
                    }.buttonStyle(.plain)
                }
                .padding(4)
                .font(.caption)
                .foregroundColor(.secondary)
                .background(.regularMaterial)
            }
        }
    }

    struct Description: View {
        var descriptions: [CodeSuggestion.Description]

        var body: some View {
            VStack(spacing: 0) {
                ForEach(0..<descriptions.count, id: \.self) { index in
                    Group {
                        switch descriptions[index].kind {
                        case .warning:
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(Image(systemName: "exclamationmark.circle.fill"))
                                Text(descriptions[index].content)
                            }
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .background(.orange.opacity(0.9))
                            
                            Divider().background(Color.red)
                        case .action:
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(Image(systemName: "arrowshape.right.circle.fill"))
                                Text(descriptions[index].content)
                            }
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .background(.cyan.opacity(0.9))
                            
                            Divider().background(Color.blue)
                        }
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                CustomScrollView {
                    WithPerceptionTracking {
                        let (code, originalCode, dimmedCharacterCount) = extractCode()
                        AsyncCodeBlock(
                            code: code,
                            originalCode: originalCode,
                            language: suggestion.language,
                            startLineIndex: suggestion.startLineIndex,
                            scenario: "suggestion",
                            font: codeFont.value.nsFont,
                            droppingLeadingSpaces: hideCommonPrecedingSpaces,
                            proposedForegroundColor: {
                                if syncHighlightTheme {
                                    if colorScheme == .light,
                                       let color = codeForegroundColorLight.value?.swiftUIColor
                                    {
                                        return color
                                    } else if let color = codeForegroundColorDark.value?
                                        .swiftUIColor
                                    {
                                        return color
                                    }
                                }
                                return nil
                            }(),
                            dimmedCharacterCount: dimmedCharacterCount
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background({ () -> Color in
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
                        }())
                    }
                }

                Description(descriptions: suggestion.descriptions)

                Divider()
                
                if suggestionDisplayCompactMode {
                    CompactToolBar(suggestion: suggestion)
                } else {
                    ToolBar(suggestion: suggestion)
                }
            }
            .xcodeStyleFrame(cornerRadius: {
                switch suggestionPresentationMode {
                case .nearbyTextCursor: 6
                case .floatingWidget: nil
                }
            }())
        }
    }

    @MainActor
    func extractCode() -> (
        code: String,
        originalCode: String,
        dimmedCharacterCount: AsyncCodeBlock.DimmedCharacterCount
    ) {
        var range = suggestion.replacingRange
        range.end = .init(line: range.end.line - range.start.line, character: range.end.character)
        range.start = .init(line: 0, character: range.start.character)
        let codeInRange = EditorInformation.code(in: suggestion.replacingLines, inside: range)
        let leftover = {
            if range.end.line >= 0, range.end.line < suggestion.replacingLines.endIndex {
                let lastLine = suggestion.replacingLines[range.end.line]
                if range.end.character < lastLine.utf16.count {
                    let startIndex = lastLine.utf16.index(
                        lastLine.utf16.startIndex,
                        offsetBy: range.end.character
                    )
                    var leftover = String(lastLine.utf16.suffix(from: startIndex))
                    if leftover?.last?.isNewline ?? false {
                        leftover?.removeLast(1)
                    }
                    return leftover ?? ""
                }
            }
            return ""
        }()

        let prefix = {
            if range.start.line >= 0, range.start.line < suggestion.replacingLines.endIndex {
                let firstLine = suggestion.replacingLines[range.start.line]
                if range.start.character < firstLine.utf16.count {
                    let endIndex = firstLine.utf16.index(
                        firstLine.utf16.startIndex,
                        offsetBy: range.start.character
                    )
                    let prefix = String(firstLine.utf16.prefix(upTo: endIndex))
                    return prefix ?? ""
                }
            }
            return ""
        }()

        let code = prefix + suggestion.code + leftover

        let typedCount = suggestion.startLineIndex == textCursorTracker.cursorPosition.line
            ? textCursorTracker.cursorPosition.character
            : 0

        return (
            code,
            codeInRange.code,
            .init(prefix: typedCount, suffix: leftover.utf16.count)
        )
    }
}

// MARK: - Previews

#Preview("Code Block Suggestion Panel") {
    CodeBlockSuggestionPanelView(suggestion: PresentingCodeSuggestion(
        code: """
        LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
        ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
            Text(viewModel.suggestion[index])
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        """,
        language: "swift",
        startLineIndex: 8,
        suggestionCount: 2,
        currentSuggestionIndex: 0,
        replacingRange: .outOfScope,
        replacingLines: []
    ), suggestionDisplayCompactMode: .init(
        wrappedValue: false,
        "suggestionDisplayCompactMode",
        store: {
            let userDefault =
                UserDefaults(suiteName: "CodeBlockSuggestionPanel_CompactToolBar_Preview")
            userDefault?.set(false, for: \.suggestionDisplayCompactMode)
            return userDefault!
        }()
    ))
    .frame(width: 450, height: 400)
    .padding()
}

#Preview("Code Block Suggestion Panel With Descriptions") {
    CodeBlockSuggestionPanelView(suggestion: PresentingCodeSuggestion(
        code: """
        LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
        ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
            Text(viewModel.suggestion[index])
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        """,
        language: "swift",
        startLineIndex: 8,
        suggestionCount: 2,
        currentSuggestionIndex: 0,
        replacingRange: .outOfScope,
        replacingLines: [],
        descriptions: [
            .init(kind: .warning, content: "This is a warning message.\nwarning"),
            .init(kind: .action, content: "This is an action message."),
        ]
    ), suggestionDisplayCompactMode: .init(
        wrappedValue: false,
        "suggestionDisplayCompactMode",
        store: {
            let userDefault =
                UserDefaults(suiteName: "CodeBlockSuggestionPanel_CompactToolBar_Preview")
            userDefault?.set(false, for: \.suggestionDisplayCompactMode)
            return userDefault!
        }()
    ))
    .frame(width: 450, height: 400)
    .padding()
}

#Preview("Code Block Suggestion Panel Compact Mode") {
    CodeBlockSuggestionPanelView(suggestion: PresentingCodeSuggestion(
        code: """
        LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
        ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
            Text(viewModel.suggestion[index])
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        """,
        language: "swift",
        startLineIndex: 8,
        suggestionCount: 2,
        currentSuggestionIndex: 0,
        replacingRange: .outOfScope,
        replacingLines: [],
        descriptions: [
            .init(kind: .warning, content: "This is a warning message."),
            .init(kind: .action, content: "This is an action message."),
        ]
    ), suggestionDisplayCompactMode: .init(
        wrappedValue: true,
        "suggestionDisplayCompactMode",
        store: {
            let userDefault =
                UserDefaults(suiteName: "CodeBlockSuggestionPanel_CompactToolBar_Preview")
            userDefault?.set(true, for: \.suggestionDisplayCompactMode)
            return userDefault!
        }()
    ))
    .preferredColorScheme(.light)
    .frame(width: 450, height: 400)
    .padding()
}

#Preview("Code Block Suggestion Panel Highlight ObjC") {
    CodeBlockSuggestionPanelView(suggestion: PresentingCodeSuggestion(
        code: """
        - (void)addSubview:(UIView *)view {
            [self addSubview:view];
        }
        """,
        language: "objective-c",
        startLineIndex: 8,
        suggestionCount: 2,
        currentSuggestionIndex: 0,
        replacingRange: .outOfScope,
        replacingLines: []
    ))
    .preferredColorScheme(.light)
    .frame(width: 450, height: 400)
    .padding()
}


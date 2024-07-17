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
    public var descriptions: [CodeSuggestion.Description]

    public init(
        code: String,
        language: String,
        startLineIndex: Int,
        suggestionCount: Int,
        currentSuggestionIndex: Int,
        replacingRange: CursorRange,
        descriptions: [CodeSuggestion.Description] = []
    ) {
        self.code = code
        self.language = language
        self.startLineIndex = startLineIndex
        self.suggestionCount = suggestionCount
        self.currentSuggestionIndex = currentSuggestionIndex
        self.replacingRange = replacingRange
        self.descriptions = descriptions
    }
}

struct CodeBlockSuggestionPanel: View {
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
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                    }.buttonStyle(.plain)

                    Text(
                        "\(suggestion.currentSuggestionIndex + 1) / \(suggestion.suggestionCount)"
                    )
                    .monospacedDigit()

                    Button(action: {
                        Task {
                            await commandHandler.presentNextSuggestion()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
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
                .padding()
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
                        Task {
                            await commandHandler.presentPreviousSuggestion()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                    }.buttonStyle(.plain)

                    Text(
                        "\(suggestion.currentSuggestionIndex + 1) / \(suggestion.suggestionCount)"
                    )
                    .monospacedDigit()

                    Button(action: {
                        Task {
                            await commandHandler.presentNextSuggestion()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
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
        let range = suggestion.replacingRange
        let codeInRange = EditorInformation.code(in: textCursorTracker.content.lines, inside: range)
        let leftover = {
            if range.end.line >= 0, range.end.line < textCursorTracker.content.lines.endIndex {
                let lastLine = textCursorTracker.content.lines[range.end.line]
                if range.end.character < lastLine.utf16.count {
                    let startIndex = lastLine.utf16.index(
                        lastLine.utf16.startIndex,
                        offsetBy: range.end.character
                    )
                    let leftover = String(lastLine.utf16.suffix(from: startIndex))
                    return leftover ?? ""
                }
            }
            return ""
        }()

        let prefix = {
            if range.start.line >= 0, range.start.line < textCursorTracker.content.lines.endIndex {
                let firstLine = textCursorTracker.content.lines[range.start.line]
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
    CodeBlockSuggestionPanel(suggestion: PresentingCodeSuggestion(
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
        replacingRange: .outOfScope
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
    CodeBlockSuggestionPanel(suggestion: PresentingCodeSuggestion(
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
        replacingRange: .outOfScope
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
    CodeBlockSuggestionPanel(suggestion: PresentingCodeSuggestion(
        code: """
        - (void)addSubview:(UIView *)view {
            [self addSubview:view];
        }
        """,
        language: "objective-c",
        startLineIndex: 8,
        suggestionCount: 2,
        currentSuggestionIndex: 0,
        replacingRange: .outOfScope
    ))
    .preferredColorScheme(.light)
    .frame(width: 450, height: 400)
    .padding()
}


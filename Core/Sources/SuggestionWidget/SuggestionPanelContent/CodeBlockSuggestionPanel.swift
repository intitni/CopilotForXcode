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

    public init(
        code: String,
        language: String,
        startLineIndex: Int,
        suggestionCount: Int,
        currentSuggestionIndex: Int
    ) {
        self.code = code
        self.language = language
        self.startLineIndex = startLineIndex
        self.suggestionCount = suggestionCount
        self.currentSuggestionIndex = currentSuggestionIndex
    }
}

struct CodeBlockSuggestionPanel: View {
    let suggestion: PresentingCodeSuggestion
    @Environment(TextCursorTracker.self) var textCursorTracker
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
                        let diffResult = Self.diff(
                            suggestion: suggestion,
                            textCursorTracker: textCursorTracker
                        )

                        AsyncCodeBlock(
                            code: suggestion.code,
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
                            dimmedCharacterCount: 0
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

    struct DiffResult {
        var dimmedRanges: [Range<String.Index>]
        var mutatedRanges: [Range<String.Index>]
        var deletedRanges: [Range<String.Index>]
    }

    @MainActor
    static func diff(
        suggestion: PresentingCodeSuggestion,
        textCursorTracker: TextCursorTracker
    ) -> DiffResult {
        let typedContentCount = suggestion.startLineIndex == textCursorTracker.cursorPosition.line
            ? textCursorTracker.cursorPosition.character
            : 0
        return .init(dimmedRanges: [], mutatedRanges: [], deletedRanges: [])
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
        currentSuggestionIndex: 0
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
        currentSuggestionIndex: 0
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
        currentSuggestionIndex: 0
    ))
    .preferredColorScheme(.light)
    .frame(width: 450, height: 400)
    .padding()
}


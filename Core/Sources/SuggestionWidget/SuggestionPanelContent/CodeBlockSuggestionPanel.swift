import Combine
import Perception
import SharedUIComponents
import SuggestionModel
import SwiftUI
import XcodeInspector

struct CodeBlockSuggestionPanel: View {
    let suggestion: CodeSuggestionProvider
    @Environment(CursorPositionTracker.self) var cursorPositionTracker
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
        let suggestion: CodeSuggestionProvider

        var body: some View {
            WithPerceptionTracking {
                HStack {
                    Button(action: {
                        suggestion.selectPreviousSuggestion()
                    }) {
                        Image(systemName: "chevron.left")
                    }.buttonStyle(.plain)

                    Text(
                        "\(suggestion.currentSuggestionIndex + 1) / \(suggestion.suggestionCount)"
                    )
                    .monospacedDigit()

                    Button(action: {
                        suggestion.selectNextSuggestion()
                    }) {
                        Image(systemName: "chevron.right")
                    }.buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        suggestion.dismissSuggestion()
                    }) {
                        Text("Dismiss").foregroundStyle(.tertiary).padding(.trailing, 4)
                    }.buttonStyle(.plain)

                    Button(action: {
                        suggestion.rejectSuggestion()
                    }) {
                        Text("Reject")
                    }.buttonStyle(CommandButtonStyle(color: .gray))

                    Button(action: {
                        suggestion.acceptSuggestion()
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
        let suggestion: CodeSuggestionProvider

        var body: some View {
            WithPerceptionTracking {
                HStack {
                    Button(action: {
                        suggestion.selectPreviousSuggestion()
                    }) {
                        Image(systemName: "chevron.left")
                    }.buttonStyle(.plain)

                    Text(
                        "\(suggestion.currentSuggestionIndex + 1) / \(suggestion.suggestionCount)"
                    )
                    .monospacedDigit()

                    Button(action: {
                        suggestion.selectNextSuggestion()
                    }) {
                        Image(systemName: "chevron.right")
                    }.buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        suggestion.dismissSuggestion()
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
                            dimmedCharacterCount: suggestion.startLineIndex
                                == cursorPositionTracker.cursorPosition.line
                                ? cursorPositionTracker.cursorPosition.character
                                : 0
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
}

// MARK: - Previews

#Preview("Code Block Suggestion Panel") {
    CodeBlockSuggestionPanel(suggestion: CodeSuggestionProvider(
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
    CodeBlockSuggestionPanel(suggestion: CodeSuggestionProvider(
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
    CodeBlockSuggestionPanel(suggestion: CodeSuggestionProvider(
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


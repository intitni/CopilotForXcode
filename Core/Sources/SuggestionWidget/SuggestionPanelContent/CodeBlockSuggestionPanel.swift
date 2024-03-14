import SharedUIComponents
import SwiftUI

struct CodeBlockSuggestionPanel: View {
    @ObservedObject var suggestion: CodeSuggestionProvider
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.suggestionCodeFontSize) var fontSize
    @AppStorage(\.suggestionDisplayCompactMode) var suggestionDisplayCompactMode
    @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode

    struct ToolBar: View {
        @ObservedObject var suggestion: CodeSuggestionProvider

        var body: some View {
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

    struct CompactToolBar: View {
        @ObservedObject var suggestion: CodeSuggestionProvider

        var body: some View {
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

    var body: some View {
        VStack(spacing: 0) {
            CustomScrollView {
                CodeBlock(
                    code: suggestion.code,
                    language: suggestion.language,
                    startLineIndex: suggestion.startLineIndex,
                    colorScheme: colorScheme,
                    fontSize: fontSize
                )
                .frame(maxWidth: .infinity)
            }
            .background(Color.contentBackground)

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


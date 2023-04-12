import SwiftUI

struct CodeBlockSuggestionPanel: View {
    @ObservedObject var suggestion: SuggestionProvider
    @Environment(\.colorScheme) var colorScheme

    struct ToolBar: View {
        @ObservedObject var suggestion: SuggestionProvider

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
                    suggestion.rejectSuggestion()
                }) {
                    Text("Reject")
                }.buttonStyle(CommandButtonStyle(color: .gray))

                Button(action: {
                    suggestion.acceptSuggestion()
                }) {
                    Text("Accept")
                }.buttonStyle(CommandButtonStyle(color: .indigo))
            }
            .padding()
            .foregroundColor(.secondary)
            .background(.regularMaterial)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                CodeBlock(
                    code: suggestion.code,
                    language: suggestion.language,
                    startLineIndex: suggestion.startLineIndex,
                    colorScheme: colorScheme
                )
                .frame(maxWidth: .infinity)
            }
            .background(Color.contentBackground)

            ToolBar(suggestion: suggestion)
        }
        .xcodeStyleFrame()
    }
}

// MARK: - Previews

struct CodeBlockSuggestionPanel_Dark_Preview: PreviewProvider {
    static var previews: some View {
        CodeBlockSuggestionPanel(suggestion: SuggestionProvider(
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
        ))
        .preferredColorScheme(.dark)
        .frame(width: 450, height: 400)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

struct CodeBlockSuggestionPanel_Bright_Preview: PreviewProvider {
    static var previews: some View {
        CodeBlockSuggestionPanel(suggestion: SuggestionProvider(
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
        ))
        .preferredColorScheme(.light)
        .frame(width: 450, height: 400)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

struct CodeBlockSuggestionPanel_Dark_Objc_Preview: PreviewProvider {
    static var previews: some View {
        CodeBlockSuggestionPanel(suggestion: SuggestionProvider(
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
        .preferredColorScheme(.dark)
        .frame(width: 450, height: 400)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

struct CodeBlockSuggestionPanel_Bright_Objc_Preview: PreviewProvider {
    static var previews: some View {
        CodeBlockSuggestionPanel(suggestion: SuggestionProvider(
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
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

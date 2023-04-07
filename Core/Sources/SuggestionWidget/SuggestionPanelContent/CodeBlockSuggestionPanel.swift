import SwiftUI

struct CodeBlock: View {
    @ObservedObject var suggestion: SuggestionProvider
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 4) {
            let code = suggestion.highlightedCode(colorScheme: colorScheme)
            ForEach(0..<code.endIndex, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(index + suggestion.startLineIndex + 1)")
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40)
                    Text(AttributedString(code[index]))
                        .foregroundColor(.white.opacity(0.1))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .overlay(alignment: .topLeading) {
                            if index == 0, suggestion.commonPrecedingSpaceCount > 0 {
                                Text("\(suggestion.commonPrecedingSpaceCount + 1)")
                                    .padding(.top, -12)
                                    .font(.footnote)
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                    .opacity(0.3)
                            }
                        }
                }
            }
        }
        .foregroundColor(.white)
        .font(.system(size: 12, design: .monospaced))
        .padding(.leading, 4)
        .padding([.trailing, .top, .bottom])
    }
}

struct CodeBlockSuggestionPanel: View {
    @ObservedObject var suggestion: SuggestionProvider

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
                CodeBlock(suggestion: suggestion)
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

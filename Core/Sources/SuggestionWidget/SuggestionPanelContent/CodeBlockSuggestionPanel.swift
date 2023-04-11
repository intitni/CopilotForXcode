import SwiftUI

struct CodeBlock: View {
    @Environment(\.colorScheme) var colorScheme

    let code: String
    let language: String
    let startLineIndex: Int

    @State var commonPrecedingSpaceCount: Int = 0
    @State var highlightedCode: [NSAttributedString] = []

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<highlightedCode.endIndex, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(index + startLineIndex + 1)")
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40)
                    Text(AttributedString(highlightedCode[index]))
                        .foregroundColor(.white.opacity(0.1))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .overlay(alignment: .topLeading) {
                            if index == 0, commonPrecedingSpaceCount > 0 {
                                Text("\(commonPrecedingSpaceCount + 1)")
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
        .onChange(of: code) { _ in
            highlightCode()
        }
        .onChange(of: colorScheme) { _ in
            highlightCode()
        }
        .onChange(of: language) { _ in
            highlightCode()
        }
        .onAppear {
            highlightCode()
        }
    }

    func highlightCode() {
        let (new, spaceCount) = highlighted(
            code: code,
            language: language,
            brightMode: colorScheme != .dark,
            droppingLeadingSpaces: UserDefaults.shared
                .value(for: \.hideCommonPrecedingSpacesInSuggestion)
        )
        highlightedCode = new
        commonPrecedingSpaceCount = spaceCount
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
                CodeBlock(
                    code: suggestion.code,
                    language: suggestion.language,
                    startLineIndex: suggestion.startLineIndex
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

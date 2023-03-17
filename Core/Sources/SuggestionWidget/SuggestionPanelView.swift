import SwiftUI

@MainActor
final class SuggestionPanelViewModel: ObservableObject {
    struct Suggestion: Equatable {
        var startLineIndex: Int
        var code: [NSAttributedString]
        var suggestionCount: Int
        var currentSuggestionIndex: Int

        static let empty = Suggestion(
            startLineIndex: 0,
            code: [],
            suggestionCount: 0,
            currentSuggestionIndex: 0
        )
    }

    @Published var suggestion: Suggestion
    @Published var isPanelDisplayed: Bool
    @Published var alignTopToAnchor = false
    @Published var colorScheme: ColorScheme

    var onAcceptButtonTapped: (() -> Void)?
    var onRejectButtonTapped: (() -> Void)?
    var onPreviousButtonTapped: (() -> Void)?
    var onNextButtonTapped: (() -> Void)?

    public init(
        suggestion: Suggestion = .empty,
        isPanelDisplayed: Bool = false,
        colorScheme: ColorScheme = .dark,
        onAcceptButtonTapped: (() -> Void)? = nil,
        onRejectButtonTapped: (() -> Void)? = nil,
        onPreviousButtonTapped: (() -> Void)? = nil,
        onNextButtonTapped: (() -> Void)? = nil
    ) {
        self.suggestion = suggestion
        self.isPanelDisplayed = isPanelDisplayed
        self.colorScheme = colorScheme
        self.onAcceptButtonTapped = onAcceptButtonTapped
        self.onRejectButtonTapped = onRejectButtonTapped
        self.onPreviousButtonTapped = onPreviousButtonTapped
        self.onNextButtonTapped = onNextButtonTapped
    }
}

struct SuggestionPanelView: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel

    var body: some View {
        VStack {
            if !viewModel.alignTopToAnchor {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ScrollView {
                        CodeBlock(viewModel: viewModel)
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color(nsColor: {
                        switch viewModel.colorScheme {
                        case .dark:
                            return #colorLiteral(red: 0.1580096483, green: 0.1730263829, blue: 0.2026666105, alpha: 1)
                        case .light:
                            return .white
                        @unknown default:
                            return .white
                        }
                    }()))

                    ToolBar(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: Style.panelHeight)
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.3), style: .init(lineWidth: 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
                    .padding(1)
            )
            .allowsHitTesting(viewModel.isPanelDisplayed && !viewModel.suggestion.code.isEmpty)
            .preferredColorScheme(viewModel.colorScheme)

            if viewModel.alignTopToAnchor {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
        .opacity({
            guard viewModel.isPanelDisplayed else { return 0 }
            guard !viewModel.suggestion.code.isEmpty else { return 0 }
            return 1
        }())
        .animation(.easeInOut(duration: 0.2), value: viewModel.suggestion)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isPanelDisplayed)
    }
}

struct CodeBlock: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel

    var body: some View {
        VStack {
            ForEach(0..<viewModel.suggestion.code.endIndex, id: \.self) { index in
                HStack(alignment: .firstTextBaseline) {
                    Text("\(index + viewModel.suggestion.startLineIndex + 1)")
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40)
                    Text(AttributedString(viewModel.suggestion.code[index]))
                        .foregroundColor(.white.opacity(0.1))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                }
            }
        }
        .foregroundColor(.white)
        .font(.system(size: 12, design: .monospaced))
        .padding()
    }
}

struct ToolBar: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel

    var body: some View {
        HStack {
            Button(action: {
                viewModel.onPreviousButtonTapped?()
            }) {
                Image(systemName: "chevron.left")
            }.buttonStyle(.plain)

            Text(
                "\(viewModel.suggestion.currentSuggestionIndex + 1) / \(viewModel.suggestion.suggestionCount)"
            )
            .monospacedDigit()

            Button(action: {
                viewModel.onNextButtonTapped?()
            }) {
                Image(systemName: "chevron.right")
            }.buttonStyle(.plain)

            Spacer()

            Button(action: {
                viewModel.onRejectButtonTapped?()
            }) {
                Text("Reject")
            }.buttonStyle(CommandButtonStyle(color: .gray))

            Button(action: {
                viewModel.onAcceptButtonTapped?()
            }) {
                Text("Accept")
            }.buttonStyle(CommandButtonStyle(color: .indigo))
        }
        .padding()
        .foregroundColor(.secondary)
        .background(.regularMaterial)
    }
}

struct CommandButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.8 : 1))
                    .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
            }
    }
}

struct SuggestionPanelView_Dark_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            suggestion: .init(
                startLineIndex: 8,
                code: highlighted(
                    code: """
                    LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
                    ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
                        Text(viewModel.suggestion[index])
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    """,
                    language: "swift",
                    brightMode: false
                ),
                suggestionCount: 2,
                currentSuggestionIndex: 0
            ),
            isPanelDisplayed: true,
            colorScheme: .dark
        ))
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

struct SuggestionPanelView_Bright_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            suggestion: .init(
                startLineIndex: 8,
                code: highlighted(
                    code: """
                    LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
                    ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
                        Text(viewModel.suggestion[index])
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    """,
                    language: "swift",
                    brightMode: true
                ),
                suggestionCount: 2,
                currentSuggestionIndex: 0
            ),
            isPanelDisplayed: true,
            colorScheme: .light
        ))
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

struct SuggestionPanelView_Dark_Objc_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            suggestion: .init(
                startLineIndex: 8,
                code: highlighted(
                    code: """
                    - (void)addSubview:(UIView *)view {
                        [self addSubview:view];
                    }
                    """,
                    language: "objective-c",
                    brightMode: false
                ),
                suggestionCount: 2,
                currentSuggestionIndex: 0
            ),
            isPanelDisplayed: true,
            colorScheme: .dark
        ))
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

struct SuggestionPanelView_Bright_Objc_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            suggestion: .init(
                startLineIndex: 8,
                code: highlighted(
                    code: """
                    - (void)addSubview:(UIView *)view {
                        [self addSubview:view];
                    }
                    """,
                    language: "objective-c",
                    brightMode: true
                ),
                suggestionCount: 2,
                currentSuggestionIndex: 0
            ),
            isPanelDisplayed: true,
            colorScheme: .light
        ))
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

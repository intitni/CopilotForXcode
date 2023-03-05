import Environment
import SwiftUI

@MainActor
final class SuggestionPanelViewModel: ObservableObject {
    @Published var startLineIndex: Int
    @Published var suggestion: [NSAttributedString]
    @Published var isPanelDisplayed: Bool
    @Published var suggestionCount: Int
    @Published var currentSuggestionIndex: Int

    var onAcceptButtonTapped: (() -> Void)?
    var onRejectButtonTapped: (() -> Void)?
    var onPreviousButtonTapped: (() -> Void)?
    var onNextButtonTapped: (() -> Void)?

    public init(
        startLineIndex: Int = 0,
        suggestion: [NSAttributedString] = [],
        isPanelDisplayed: Bool = false,
        suggestionCount: Int = 0,
        currentSuggestionIndex: Int = 0,
        onAcceptButtonTapped: (() -> Void)? = nil,
        onRejectButtonTapped: (() -> Void)? = nil,
        onPreviousButtonTapped: (() -> Void)? = nil,
        onNextButtonTapped: (() -> Void)? = nil
    ) {
        self.startLineIndex = startLineIndex
        self.suggestion = suggestion
        self.isPanelDisplayed = isPanelDisplayed
        self.suggestionCount = suggestionCount
        self.currentSuggestionIndex = currentSuggestionIndex
        self.onAcceptButtonTapped = onAcceptButtonTapped
        self.onRejectButtonTapped = onRejectButtonTapped
        self.onPreviousButtonTapped = onPreviousButtonTapped
        self.onNextButtonTapped = onNextButtonTapped
    }
}

struct SuggestionPanelView: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel
    @State var isHovering: Bool = false
    @State var codeHeight: Double = 0
    let backgroundColor = #colorLiteral(red: 0.1580096483, green: 0.1730263829, blue: 0.2026666105, alpha: 1)

    var body: some View {
        VStack {
            Spacer()
                .frame(minHeight: 0, maxHeight: .infinity)
                .allowsHitTesting(false)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ScrollView {
                        CodeBlock(viewModel: viewModel)
                    }
                    .background(Color(nsColor: backgroundColor))

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

            .onHover { yes in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = yes
                }
            }
            .allowsHitTesting(viewModel.isPanelDisplayed && !viewModel.suggestion.isEmpty)
            .preferredColorScheme(.dark)
        }
        .opacity({
            guard viewModel.isPanelDisplayed else { return 0 }
            guard !viewModel.suggestion.isEmpty else { return 0 }
            return 1
        }())
    }
}

struct CodeBlock: View {
    struct SizePreferenceKey: PreferenceKey {
        public static var defaultValue: CGSize = .zero
        public static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
            value = value.width + value.height > nextValue().width + nextValue()
                .height ? value : nextValue()
        }
    }

    @ObservedObject var viewModel: SuggestionPanelViewModel

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.fixed(30), alignment: .top),
            GridItem(.flexible()),
        ], spacing: 4) {
            ForEach(0..<viewModel.suggestion.count, id: \.self) { index in
                Text("\(index + viewModel.startLineIndex + 1)")
                    .foregroundColor(Color.white.opacity(0.6))
                Text(AttributedString(viewModel.suggestion[index]))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
            }
        }
        .foregroundColor(.white)
        .font(.system(size: 12, design: .monospaced))
        .padding()
        .background(GeometryReader(content: { proxy in
            Color.clear.preference(key: SizePreferenceKey.self, value: proxy.size)
        }))
    }
}

struct ToolBar: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel

    var body: some View {
        HStack {
            Button(action: {
                Task {
                    if let block = viewModel.onPreviousButtonTapped {
                        block()
                        return
                    }
                    try await Environment.triggerAction("Previous Suggestion")
                }
            }) {
                Image(systemName: "chevron.left")
            }.buttonStyle(.plain)

            Text("\(viewModel.currentSuggestionIndex + 1) / \(viewModel.suggestionCount)")
                .monospacedDigit()

            Button(action: {
                Task {
                    if let block = viewModel.onNextButtonTapped {
                        block()
                        return
                    }
                    try await Environment.triggerAction("Next Suggestion")
                }
            }) {
                Image(systemName: "chevron.right")
            }.buttonStyle(.plain)

            Spacer()

            Button(action: {
                Task {
                    if let block = viewModel.onRejectButtonTapped {
                        block()
                        return
                    }
                    try await Environment.triggerAction("Reject Suggestion")
                }
            }) {
                Text("Reject")
            }.buttonStyle(CommandButtonStyle(color: .gray))

            Button(action: {
                Task {
                    if let block = viewModel.onAcceptButtonTapped {
                        block()
                        return
                    }
                    try await Environment.triggerAction("Accept Suggestion")
                }
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

struct SuggestionPanelView_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            startLineIndex: 8,
            suggestion:
            highlighted(
                code: """
                LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
                ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
                    Text(viewModel.suggestion[index])
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                """,
                language: "swift"
            ),
            isPanelDisplayed: true
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

import Environment
import SwiftUI

@MainActor
final class SuggestionPanelViewModel: ObservableObject {
    @Published var startLineIndex: Int
    @Published var suggestion: [String]
    @Published var isPanelDisplayed: Bool
    @Published var suggestionCount: Int
    @Published var currentSuggestionIndex: Int

    public init(
        startLineIndex: Int = 0,
        suggestion: [String] = [],
        isPanelDisplayed: Bool = false,
        suggestionCount: Int = 0,
        currentSuggestionIndex: Int = 0
    ) {
        self.startLineIndex = startLineIndex
        self.suggestion = suggestion
        self.isPanelDisplayed = isPanelDisplayed
        self.suggestionCount = suggestionCount
        self.currentSuggestionIndex = currentSuggestionIndex
    }
}

struct SuggestionPanelView: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel
    @State var isHovering: Bool = false
    @State var codeHeight: Double = 0

    var body: some View {
        // weird, if the if statement is at the top level, the view may not update sometimes.
        VStack {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.fixed(30), alignment: .top),
                            GridItem(.flexible()),
                        ], spacing: 4) {
                            ForEach(0..<viewModel.suggestion.count, id: \.self) { index in
                                Text("\(index + viewModel.startLineIndex + 1)")
                                    .foregroundColor(Color.white.opacity(0.6))
                                Text(viewModel.suggestion[index])
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(4)
                            }
                        }
                        .foregroundColor(.white)
                        .font(.system(size: 12, design: .monospaced))
                        .padding()
                        .background(
                            GeometryReader { proxy -> Color in
                                Task {
                                    codeHeight = proxy.size.height
                                }
                                return Color.clear
                            }
                        )

                        Spacer()
                    }
                    .frame(height: min(codeHeight, 300))

                    HStack {
                        Text("\(viewModel.currentSuggestionIndex)/\(viewModel.suggestionCount)")

                        Spacer()

                        Button(action: {
                            Task {
                                try await Environment.triggerAction("Accept Suggestion")
                            }
                        }) {
                            Text("Accept")
                        }.buttonStyle(CommandButtonStyle(color: .green))
                        Button(action: {
                            Task {
                                try await Environment.triggerAction("Reject Suggestion")
                            }
                        }) {
                            Text("Reject")
                        }.buttonStyle(CommandButtonStyle(color: .red))
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.1))
                }
            }
            .background(Color(red: 31 / 255, green: 31 / 255, blue: 36 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity({
                guard viewModel.isPanelDisplayed else { return 0 }
                guard !viewModel.suggestion.isEmpty else { return 0 }
                return 1
            }())
            .frame(maxWidth: .infinity)
            .onHover { yes in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = yes
                }
            }
            .allowsHitTesting(viewModel.isPanelDisplayed && !viewModel.suggestion.isEmpty)

            Spacer()
                .frame(minHeight: 0, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
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
            """
            LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
                ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
                    Text(viewModel.suggestion[index])
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            """.split(separator: "\n").map(String.init),
            isPanelDisplayed: true
        ))
        .frame(width: 450, height: 400)
    }
}

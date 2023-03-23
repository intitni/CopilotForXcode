import SwiftUI

struct CodeBlock: View {
    var suggestion: SuggestionPanelViewModel.Suggestion

    var body: some View {
        VStack {
            ForEach(0..<suggestion.code.endIndex, id: \.self) { index in
                HStack(alignment: .firstTextBaseline) {
                    Text("\(index + suggestion.startLineIndex + 1)")
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40)
                    Text(AttributedString(suggestion.code[index]))
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

struct CodeBlockSuggestionPanel: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel
    var suggestion: SuggestionPanelViewModel.Suggestion

    struct ToolBar: View {
        @ObservedObject var viewModel: SuggestionPanelViewModel
        var suggestion: SuggestionPanelViewModel.Suggestion

        var body: some View {
            HStack {
                Button(action: {
                    viewModel.onPreviousButtonTapped?()
                }) {
                    Image(systemName: "chevron.left")
                }.buttonStyle(.plain)

                Text(
                    "\(suggestion.currentSuggestionIndex + 1) / \(suggestion.suggestionCount)"
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

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                CodeBlock(suggestion: suggestion)
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

            ToolBar(viewModel: viewModel, suggestion: suggestion)
        }
    }
}

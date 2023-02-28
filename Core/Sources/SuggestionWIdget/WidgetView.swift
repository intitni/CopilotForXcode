import SwiftUI

@MainActor
final class WidgetViewModel: ObservableObject {
    enum Position {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    var position: Position = .topRight
    @Published var isProcessing: Bool = false

    init() {}
}

struct WidgetView: View {
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var panelViewModel: SuggestionPanelViewModel
    @State var isHovering = false

    var body: some View {
        Circle().fill(isHovering ? .white.opacity(0.8) : .white.opacity(0.3))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    panelViewModel.isPanelDisplayed.toggle()
                }
            }
            .overlay {
                Circle()
                    .stroke(
                        panelViewModel.suggestion.isEmpty
                            ? Color(nsColor: .darkGray)
                            : Color.accentColor,
                        style: .init(lineWidth: 4)
                    )
                    .padding(2)
            }
            .overlay {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.primary)
                        .scaleEffect(x: 0.5, y: 0.5)
                }
            }
            .onHover { yes in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = yes
                }
            }
    }
}

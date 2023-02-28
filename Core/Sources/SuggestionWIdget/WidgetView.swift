import SwiftUI

@MainActor
final class WidgetViewModel: ObservableObject {
    enum Position {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    var position: Position
    @Published var isProcessing: Bool

    init(position: Position = .topRight, isProcessing: Bool = false) {
        self.position = position
        self.isProcessing = isProcessing
    }
}

struct WidgetView: View {
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var panelViewModel: SuggestionPanelViewModel
    @State var isHovering: Bool = false
    @State var processingProgress: Double = 0

    var body: some View {
        Circle().fill(isHovering ? .white.opacity(0.8) : .white.opacity(0.3))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    panelViewModel.isPanelDisplayed.toggle()
                }
            }
            .overlay {
                let lineWidth: Double = 4
                
                Circle()
                    .stroke(
                        panelViewModel.suggestion.isEmpty
                            ? Color(nsColor: .darkGray)
                            : Color.accentColor,
                        style: .init(lineWidth: lineWidth)
                    )
                    .padding(lineWidth / 2)
            }
            .overlay {
                if viewModel.isProcessing {
                    animationgRing()
                }
            }
            .onHover { yes in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = yes
                }
            }
    }
    
    @ViewBuilder
    func animationgRing() -> some View {
        let lineWidth = processingProgress * 5 + 4
        
        Circle()
            .stroke(
                Color.accentColor,
                style: .init(lineWidth: lineWidth)
            )
            .onAppear {
                Task {
                    await Task.yield()
                    withAnimation(
                        .easeInOut(duration: 1)
                            .repeatForever(
                                autoreverses: true
                            )
                    ) {
                        processingProgress = 1
                    }
                }
            }
            .padding(lineWidth / 2)
    }
}

struct WidgetView_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            WidgetView(
                viewModel: .init(position: .topRight, isProcessing: false),
                panelViewModel: .init(),
                isHovering: false
            )

            WidgetView(
                viewModel: .init(position: .topRight, isProcessing: false),
                panelViewModel: .init(),
                isHovering: true
            )

            WidgetView(
                viewModel: .init(position: .topRight, isProcessing: true),
                panelViewModel: .init(),
                isHovering: false
            )

            WidgetView(
                viewModel: .init(position: .topRight, isProcessing: false),
                panelViewModel: .init(suggestion: ["Hello"]),
                isHovering: false
            )
        }
        .frame(width: 40)
        .background(Color.black)
    }
}

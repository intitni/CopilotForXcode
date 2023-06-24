import Foundation
import SwiftUI

@MainActor
final class SuggestionPanelDisplayController: ObservableObject {
    @Published var alignTopToAnchor = false
    @Published var isPanelOutOfFrame: Bool = false
    @Published var isPanelDisplayed: Bool = false

    init(
        alignTopToAnchor: Bool = false,
        isPanelOutOfFrame: Bool = false,
        isPanelDisplayed: Bool = false
    ) {
        self.alignTopToAnchor = alignTopToAnchor
        self.isPanelDisplayed = isPanelDisplayed
        self.isPanelOutOfFrame = isPanelOutOfFrame
    }
}

struct SuggestionPanelView: View {
    @ObservedObject var viewModel: SharedPanelViewModel
    @ObservedObject var displayController: SuggestionPanelDisplayController
    @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode

    var body: some View {
        VStack(spacing: 0) {
            if !displayController.alignTopToAnchor {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            VStack {
                if let content = viewModel.content {
                    ZStack(alignment: .topLeading) {
                        switch content {
                        case let .suggestion(suggestion):
                            switch suggestionPresentationMode {
                            case .nearbyTextCursor:
                                CodeBlockSuggestionPanel(suggestion: suggestion)
                            case .floatingWidget:
                                EmptyView()
                            }
                        default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: Style.inlineSuggestionMaxHeight)
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(
                        displayController.isPanelDisplayed && !displayController.isPanelOutOfFrame
                    )
                }
            }
            .frame(maxWidth: .infinity)

            if displayController.alignTopToAnchor {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(viewModel.colorScheme)
        .opacity({
            guard displayController.isPanelDisplayed else { return 0 }
            guard !displayController.isPanelOutOfFrame else { return 0 }
            guard viewModel.content != nil else { return 0 }
            return 1
        }())
        .animation(
            featureFlag: \.animationACrashSuggestion,
            .easeInOut(duration: 0.2),
            value: viewModel.content?.contentHash
        )
        .animation(
            featureFlag: \.animationBCrashSuggestion,
            .easeInOut(duration: 0.2),
            value: displayController.isPanelDisplayed
        )
        .animation(
            featureFlag: \.animationBCrashSuggestion,
            .easeInOut(duration: 0.2),
            value: displayController.isPanelOutOfFrame
        )
        .frame(maxWidth: Style.inlineSuggestionMinWidth, maxHeight: Style.inlineSuggestionMaxHeight)
    }
}


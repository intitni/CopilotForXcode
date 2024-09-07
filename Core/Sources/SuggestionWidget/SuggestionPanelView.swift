import ComposableArchitecture
import Foundation
import SwiftUI

struct SuggestionPanelView: View {
    let store: StoreOf<SuggestionPanel>

    struct OverallState: Equatable {
        var isPanelDisplayed: Bool
        var opacity: Double
        var colorScheme: ColorScheme
        var isPanelOutOfFrame: Bool
        var alignTopToAnchor: Bool
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                if !store.alignTopToAnchor {
                    Spacer()
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }

                Content(store: store)
                    .allowsHitTesting(
                        store.isPanelDisplayed && !store.isPanelOutOfFrame
                    )
                    .frame(maxWidth: .infinity)

                if store.alignTopToAnchor {
                    Spacer()
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
            }
            .preferredColorScheme(store.colorScheme)
            .opacity(store.opacity)
            .animation(
                featureFlag: \.animationBCrashSuggestion,
                .easeInOut(duration: 0.2),
                value: store.isPanelDisplayed
            )
            .animation(
                featureFlag: \.animationBCrashSuggestion,
                .easeInOut(duration: 0.2),
                value: store.isPanelOutOfFrame
            )
            .frame(
                maxWidth: Style.inlineSuggestionMinWidth,
                maxHeight: Style.inlineSuggestionMaxHeight
            )
        }
    }

    struct Content: View {
        let store: StoreOf<SuggestionPanel>
        @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode

        var body: some View {
            WithPerceptionTracking {
                if let content = store.content {
                    ZStack(alignment: .topLeading) {
                        switch suggestionPresentationMode {
                        case .nearbyTextCursor:
                            CodeBlockSuggestionPanelView(suggestion: content)
                        case .floatingWidget:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: Style.inlineSuggestionMaxHeight)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}


import ComposableArchitecture
import Foundation
import SwiftUI

struct SuggestionPanelView: View {
    let store: SuggestionPanel

    struct OverallState: Equatable {
        var isPanelDisplayed: Bool
        var opacity: Double
        var colorScheme: ColorScheme
        var isPanelOutOfFrame: Bool
        var alignTopToAnchor: Bool
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                if store.verticalAlignment == .bottom {
                    Spacer()
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }

                Content(store: store)
                    .allowsHitTesting(
                        store.isPanelDisplayed && !store.isPanelOutOfFrame
                    )
                    .frame(maxWidth: .infinity)

                if store.verticalAlignment == .top {
                    Spacer()
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
            }
            .preferredColorScheme(store.colorScheme)
            .opacity(store.opacity)
        }
    }

    struct Content: View {
        let store: SuggestionPanel
        @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode

        var body: some View {
            WithPerceptionTracking {
                if let suggestionManager = store.suggestionManager {
                    SuggestionPanelGroupView(
                        manager: suggestionManager,
                        alignment: .leading
                    )
                    .frame(width: Style.inlineSuggestionMinWidth)
                    .frame(maxHeight: Style.inlineSuggestionMaxHeight)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}


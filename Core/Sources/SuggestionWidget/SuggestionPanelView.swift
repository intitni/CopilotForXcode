import ComposableArchitecture
import Foundation
import SwiftUI

struct SuggestionPanelView: View {
    let store: StoreOf<SuggestionPanelFeature>
    @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode

    struct OverallState: Equatable {
        var isPanelDisplayed: Bool
        var opacity: Double
        var colorScheme: ColorScheme
        var isPanelOutOfFrame: Bool
        var alignTopToAnchor: Bool
    }

    var body: some View {
        WithViewStore(
            store,
            observe: { OverallState(
                isPanelDisplayed: $0.isPanelDisplayed,
                opacity: $0.opacity,
                colorScheme: $0.colorScheme,
                isPanelOutOfFrame: $0.isPanelOutOfFrame,
                alignTopToAnchor: $0.alignTopToAnchor
            ) }
        ) { viewStore in
            VStack(spacing: 0) {
                if !viewStore.alignTopToAnchor {
                    Spacer()
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }

                IfLetStore(store.scope(state: \.content, action: { $0 })) { store in
                    WithViewStore(store) { viewStore in
                        ZStack(alignment: .topLeading) {
                            switch suggestionPresentationMode {
                            case .nearbyTextCursor:
                                CodeBlockSuggestionPanel(suggestion: viewStore.state)
                            case .floatingWidget:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: Style.inlineSuggestionMaxHeight)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .allowsHitTesting(
                    viewStore.isPanelDisplayed && !viewStore.isPanelOutOfFrame
                )
                .frame(maxWidth: .infinity)

                if viewStore.alignTopToAnchor {
                    Spacer()
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
            }
            .preferredColorScheme(viewStore.colorScheme)
            .opacity(viewStore.opacity)
            .animation(
                featureFlag: \.animationBCrashSuggestion,
                .easeInOut(duration: 0.2),
                value: viewStore.isPanelDisplayed
            )
            .animation(
                featureFlag: \.animationBCrashSuggestion,
                .easeInOut(duration: 0.2),
                value: viewStore.isPanelOutOfFrame
            )
            .frame(
                maxWidth: Style.inlineSuggestionMinWidth,
                maxHeight: Style.inlineSuggestionMaxHeight
            )
        }
    }
}


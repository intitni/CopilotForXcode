import ComposableArchitecture
import Preferences
import SwiftUI

extension View {
    @ViewBuilder
    func animation<V: Equatable>(
        featureFlag: KeyPath<UserDefaultPreferenceKeys, FeatureFlag>,
        _ animation: Animation?,
        value: V
    ) -> some View {
        let isOn = UserDefaults.shared.value(for: featureFlag)
        if isOn {
            self.animation(animation, value: value)
        } else {
            self
        }
    }
}

struct SharedPanelView: View {
    var store: StoreOf<SharedPanel>

    struct OverallState: Equatable {
        var isPanelDisplayed: Bool
        var opacity: Double
        var colorScheme: ColorScheme
        var alignTopToAnchor: Bool
    }

    var body: some View {
        GeometryReader { geometry in
            WithPerceptionTracking {
                VStack(spacing: 0) {
                    if !store.alignTopToAnchor {
                        Spacer()
                            .frame(minHeight: 0, maxHeight: .infinity)
                            .allowsHitTesting(false)
                    }

                    DynamicContent(store: store)
                        .frame(maxWidth: .infinity, maxHeight: geometry.size.height)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(store.isPanelDisplayed)
                        .layoutPriority(1)

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
                .frame(maxWidth: Style.panelWidth, maxHeight: .infinity)
            }
        }
    }

    struct DynamicContent: View {
        let store: StoreOf<SharedPanel>

        @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode

        var body: some View {
            WithPerceptionTracking {
                ZStack(alignment: .topLeading) {
                    promptToCode()
                }
            }
        }

        @ViewBuilder
        func promptToCode() -> some View {
            PromptToCodePanelGroupView(store: store.scope(
                state: \.content.promptToCodeGroup,
                action: \.promptToCodeGroup
            ))
        }
    }
}

struct CommandButtonStyle: ButtonStyle {
    var color: Color
    var cornerRadius: Double = 4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.8 : 1))
                    .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
            }
    }
}

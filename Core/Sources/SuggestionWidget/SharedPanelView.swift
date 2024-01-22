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
    var store: StoreOf<SharedPanelFeature>
    @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode

    struct OverallState: Equatable {
        var isPanelDisplayed: Bool
        var opacity: Double
        var colorScheme: ColorScheme
        var alignTopToAnchor: Bool
    }

    var body: some View {
        WithViewStore(
            store,
            observe: { OverallState(
                isPanelDisplayed: $0.isPanelDisplayed,
                opacity: $0.opacity,
                colorScheme: $0.colorScheme,
                alignTopToAnchor: $0.alignTopToAnchor
            ) }
        ) { viewStore in
            VStack(spacing: 0) {
                if !viewStore.state.alignTopToAnchor {
                    Spacer()
                        .frame(minHeight: 0, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }

                WithViewStore(store, observe: { $0.content }) { viewStore in
                    ZStack(alignment: .topLeading) {
                        if let error = viewStore.state.error {
                            ErrorPanel(description: error) {
                                viewStore.send(
                                    .errorMessageCloseButtonTapped,
                                    animation: .easeInOut(duration: 0.2)
                                )
                            }
                        } else if let _ = viewStore.state.promptToCode {
                            IfLetStore(store.scope(
                                state: { $0.content.promptToCodeGroup.activePromptToCode },
                                action: {
                                    SharedPanelFeature.Action
                                        .promptToCodeGroup(.activePromptToCode($0))
                                }
                            )) {
                                PromptToCodePanel(store: $0)
                            }

                        } else if let suggestion = viewStore.state.suggestion {
                            switch suggestionPresentationMode {
                            case .nearbyTextCursor:
                                EmptyView()
                            case .floatingWidget:
                                CodeBlockSuggestionPanel(suggestion: suggestion)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: Style.panelHeight)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .allowsHitTesting(viewStore.isPanelDisplayed)
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
            .frame(maxWidth: Style.panelWidth, maxHeight: Style.panelHeight)
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

// MARK: - Previews

struct SharedPanelView_Error_Preview: PreviewProvider {
    static var previews: some View {
        SharedPanelView(store: .init(
            initialState: .init(
                content: .init(error: "This is an error\nerror"),
                colorScheme: .light,
                isPanelDisplayed: true
            ),
            reducer: SharedPanelFeature()
        ))
        .frame(width: 450, height: 200)
    }
}

struct SharedPanelView_Both_DisplayingSuggestion_Preview: PreviewProvider {
    static var previews: some View {
        SharedPanelView(store: .init(
            initialState: .init(
                content: .init(
                    suggestion: .init(
                        code: """
                        - (void)addSubview:(UIView *)view {
                            [self addSubview:view];
                        }
                        """,
                        language: "objective-c",
                        startLineIndex: 8,
                        suggestionCount: 2,
                        currentSuggestionIndex: 0
                    )
                ),
                colorScheme: .dark,
                isPanelDisplayed: true
            ),
            reducer: SharedPanelFeature()
        ))
        .frame(width: 450, height: 200)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}


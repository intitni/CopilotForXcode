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

    struct OverallState: Equatable {
        var isPanelDisplayed: Bool
        var opacity: Double
        var colorScheme: ColorScheme
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

                DynamicContent(store: store)

                    .frame(maxWidth: .infinity, maxHeight: Style.panelHeight)
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(store.isPanelDisplayed)
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
            .frame(maxWidth: Style.panelWidth, maxHeight: Style.panelHeight)
        }
    }

    struct DynamicContent: View {
        let store: StoreOf<SharedPanelFeature>

        @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode

        var body: some View {
            WithPerceptionTracking {
                ZStack(alignment: .topLeading) {
                    if let errorMessage = store.content.error {
                        error(errorMessage)
                    } else if let _ = store.content.promptToCode {
                        promptToCode()
                    } else if let suggestionProvider = store.content.suggestion {
                        suggestion(suggestionProvider)
                    }
                }
            }
        }

        @ViewBuilder
        func error(_ error: String) -> some View {
            ErrorPanel(description: error) {
                store.send(
                    .errorMessageCloseButtonTapped,
                    animation: .easeInOut(duration: 0.2)
                )
            }
        }

        @ViewBuilder
        func promptToCode() -> some View {
            if let store = store.scope(
                state: \.content.promptToCodeGroup.activePromptToCode,
                action: \.promptToCodeGroup.activePromptToCode
            ) {
                PromptToCodePanel(store: store)
            }
        }

        @ViewBuilder
        func suggestion(_ suggestion: CodeSuggestionProvider) -> some View {
            switch suggestionPresentationMode {
            case .nearbyTextCursor:
                EmptyView()
            case .floatingWidget:
                CodeBlockSuggestionPanel(suggestion: suggestion)
            }
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
            reducer: { SharedPanelFeature() }
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
            reducer: { SharedPanelFeature() }
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


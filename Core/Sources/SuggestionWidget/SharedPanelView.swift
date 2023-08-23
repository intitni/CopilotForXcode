import ComposableArchitecture
import Environment
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
        var contentHash: String
        var alignTopToAnchor: Bool
    }

    var body: some View {
        WithViewStore(
            store,
            observe: { OverallState(
                isPanelDisplayed: $0.isPanelDisplayed,
                opacity: $0.opacity,
                colorScheme: $0.colorScheme,
                contentHash: $0.content?.contentHash ?? "",
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
                            switch viewStore.state {
                            case let .suggestion(suggestion):
                                switch suggestionPresentationMode {
                                case .nearbyTextCursor:
                                    EmptyView()
                                case .floatingWidget:
                                    CodeBlockSuggestionPanel(suggestion: suggestion)
                                }
                            case let .promptToCode(provider):
                                PromptToCodePanel(provider: provider)
                            case let .error(description):
                                ErrorPanel(description: description) {
                                    viewStore.send(
                                        .closeButtonTapped,
                                        animation: .easeInOut(duration: 0.2)
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: Style.panelHeight)
                        .fixedSize(horizontal: false, vertical: true)
                    }
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

struct SuggestionPanelView_Error_Preview: PreviewProvider {
    static var previews: some View {
        SharedPanelView(store: .init(
            initialState: .init(
                content: .error("This is an error\nerror"),
                colorScheme: .light,
                isPanelDisplayed: true
            ),
            reducer: SharedPanelFeature()
        ))
        .frame(width: 450, height: 200)
    }
}

struct SuggestionPanelView_Both_DisplayingSuggestion_Preview: PreviewProvider {
    static var previews: some View {
        SharedPanelView(store: .init(
            initialState: .init(
                content: .suggestion(
                    SuggestionProvider(
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


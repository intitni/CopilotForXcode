import AppKit
import ComposableArchitecture
import Foundation

@Reducer
public struct WidgetPanel {
    @ObservableState
    public struct State {
        public var content: SharedPanel.Content {
            get { sharedPanelState.content }
            set {
                sharedPanelState.content = newValue
                suggestionPanelState.content = newValue.suggestion
            }
        }

        // MARK: SharedPanel

        var sharedPanelState = SharedPanel.State()

        // MARK: SuggestionPanel

        var suggestionPanelState = SuggestionPanel.State()
    }

    public enum Action {
        case presentSuggestion
        case presentSuggestionProvider(PresentingCodeSuggestion, displayContent: Bool)
        case presentError(String)
        case presentPromptToCode(PromptToCodePanel.State)
        case displayPanelContent
        case discardSuggestion
        case removeDisplayedContent
        case switchToAnotherEditorAndUpdateContent

        case sharedPanel(SharedPanel.Action)
        case suggestionPanel(SuggestionPanel.Action)
    }

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.activateThisApp) var activateThisApp
    var windows: WidgetWindows? { suggestionWidgetControllerDependency.windowsController?.windows }

    public var body: some ReducerOf<Self> {
        Scope(state: \.suggestionPanelState, action: \.suggestionPanel) {
            SuggestionPanel()
        }

        Scope(state: \.sharedPanelState, action: \.sharedPanel) {
            SharedPanel()
        }

        Reduce { state, action in
            switch action {
            case .presentSuggestion:
                return .run { send in
                    guard let fileURL = await xcodeInspector.safe.activeDocumentURL,
                          let provider = await fetchSuggestionProvider(fileURL: fileURL)
                    else { return }
                    await send(.presentSuggestionProvider(provider, displayContent: true))
                }

            case let .presentSuggestionProvider(provider, displayContent):
                state.content.suggestion = provider
                if displayContent {
                    return .run { send in
                        await send(.displayPanelContent)
                    }.animation(.easeInOut(duration: 0.2))
                }
                return .none

            case let .presentError(errorDescription):
                state.content.error = errorDescription
                return .run { send in
                    await send(.displayPanelContent)
                }.animation(.easeInOut(duration: 0.2))

            case let .presentPromptToCode(initialState):
                return .run { send in
                    await send(.sharedPanel(.promptToCodeGroup(.createPromptToCode(initialState))))
                }

            case .displayPanelContent:
                if !state.sharedPanelState.isEmpty {
                    state.sharedPanelState.isPanelDisplayed = true
                }

                if state.suggestionPanelState.content != nil {
                    state.suggestionPanelState.isPanelDisplayed = true
                }

                return .none

            case .discardSuggestion:
                state.content.suggestion = nil
                return .none

            case .switchToAnotherEditorAndUpdateContent:
                return .run { send in
                    guard let fileURL = await xcodeInspector.safe.realtimeActiveDocumentURL
                    else { return }

                    await send(.sharedPanel(
                        .promptToCodeGroup(
                            .updateActivePromptToCode(documentURL: fileURL)
                        )
                    ))
                }

            case .removeDisplayedContent:
                state.content.error = nil
                state.content.suggestion = nil
                return .none

            case .sharedPanel(.promptToCodeGroup(.activateOrCreatePromptToCode)),
                 .sharedPanel(.promptToCodeGroup(.createPromptToCode)):
                let hasPromptToCode = state.content.promptToCode != nil
                return .run { send in
                    await send(.displayPanelContent)

                    if hasPromptToCode {
                        activateThisApp()
                        await MainActor.run {
                            windows?.sharedPanelWindow.makeKey()
                        }
                    }
                }.animation(.easeInOut(duration: 0.2))

            case .sharedPanel:
                return .none

            case .suggestionPanel:
                return .none
            }
        }
    }

    func fetchSuggestionProvider(fileURL: URL) async -> PresentingCodeSuggestion? {
        guard let provider = await suggestionWidgetControllerDependency
            .suggestionWidgetDataSource?
            .suggestionForFile(at: fileURL) else { return nil }
        return provider
    }
}


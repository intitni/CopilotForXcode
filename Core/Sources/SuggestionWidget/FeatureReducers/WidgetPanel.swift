import AppKit
import ComposableArchitecture
import Foundation

@Reducer
public struct WidgetPanel {
    @ObservableState
    public struct State {
        public var content: SharedPanel.Content {
            get { sharedPanelState.content }
            set { sharedPanelState.content = newValue }
        }

        // MARK: SharedPanel

        var sharedPanelState = SharedPanel.State()
    }

    public enum Action {
        case presentPromptToCode(PromptToCodePanel.State)
        case displayPanelContent
        case switchToAnotherEditorAndUpdateContent

        case sharedPanel(SharedPanel.Action)
    }

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.activateThisApp) var activateThisApp
    var windows: WidgetWindows? { suggestionWidgetControllerDependency.windowsController?.windows }

    public var body: some ReducerOf<Self> {
        Scope(state: \.sharedPanelState, action: \.sharedPanel) {
            SharedPanel()
        }

        Reduce { state, action in
            switch action {
            case let .presentPromptToCode(initialState):
                return .run { send in
                    await send(.sharedPanel(.promptToCodeGroup(.createPromptToCode(
                        initialState,
                        sendImmediately: true
                    ))))
                }

            case .displayPanelContent:
                if !state.sharedPanelState.isEmpty {
                    state.sharedPanelState.isPanelDisplayed = true
                }

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

            case .sharedPanel(.promptToCodeGroup(.activateOrCreatePromptToCode)),
                 .sharedPanel(.promptToCodeGroup(.createPromptToCode)):
                let hasPromptToCode = !state.content.promptToCodeGroup.promptToCodes.isEmpty
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
            }
        }
    }
}


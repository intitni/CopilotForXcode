import AppKit
import ComposableArchitecture
import Foundation

public struct PanelFeature: ReducerProtocol {
    public struct State: Equatable {
        var content: SharedPanelFeature.Content? {
            get { sharedPanelState.content ?? suggestionPanelState.content }
            set {
                sharedPanelState.content = newValue
                suggestionPanelState.content = newValue
            }
        }

        // MARK: SharedPanel

        var sharedPanelState = SharedPanelFeature.State()

        // MARK: SuggestionPanel

        var suggestionPanelState = SuggestionPanelFeature.State()
    }

    public enum Action: Equatable {
        case presentSuggestion
        case presentError(String)
        case presentPromptToCode
        case presentPanelContent(SharedPanelFeature.Content, shouldDisplay: Bool)
        case discardPanelContent
        case removeDisplayedContent
        case switchToAnotherEditorAndUpdateContent

        case sharedPanel(SharedPanelFeature.Action)
        case suggestionPanel(SuggestionPanelFeature.Action)
    }

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    var windows: WidgetWindows { suggestionWidgetControllerDependency.windows }

    public var body: some ReducerProtocol<State, Action> {
        Scope(state: \.suggestionPanelState, action: /Action.suggestionPanel) {
            SuggestionPanelFeature()
        }

        Scope(state: \.sharedPanelState, action: /Action.sharedPanel) {
            SharedPanelFeature()
        }

        Reduce { state, action in
            switch action {
            case .presentSuggestion:
                return .run { send in
                    guard let provider = await fetchSuggestionProvider(
                        fileURL: xcodeInspector.activeDocumentURL
                    ) else { return }
                    let content = SharedPanelFeature.Content.suggestion(provider)
                    await send(.presentPanelContent(content, shouldDisplay: true))
                }.animation(.easeInOut(duration: 0.2))

            case let .presentError(errorDescription):
                return .run { send in
                    let content = SharedPanelFeature.Content.error(errorDescription)
                    await send(.presentPanelContent(content, shouldDisplay: true))
                }.animation(.easeInOut(duration: 0.2))

            case .presentPromptToCode:
                return .run { send in
                    guard let provider = await fetchPromptToCodeProvider(
                        fileURL: xcodeInspector.activeDocumentURL
                    ) else { return }
                    let content = SharedPanelFeature.Content.promptToCode(provider)
                    await send(.presentPanelContent(content, shouldDisplay: true))

                    // looks like we need a delay.
                    try await Task.sleep(nanoseconds: 150_000_000)
                    await NSApplication.shared.activate(ignoringOtherApps: true)
                    await windows.sharedPanelWindow.makeKey()
                }.animation(.easeInOut(duration: 0.2))

            case let .presentPanelContent(content, shouldDisplay):
                state.content = content

                guard shouldDisplay else { return .none }

                switch content {
                case .suggestion:
                    switch UserDefaults.shared.value(for: \.suggestionPresentationMode) {
                    case .nearbyTextCursor:
                        state.suggestionPanelState.isPanelDisplayed = true
                    case .floatingWidget:
                        state.sharedPanelState.isPanelDisplayed = true
                    }
                case .error:
                    state.sharedPanelState.isPanelDisplayed = true
                case .promptToCode:
                    state.sharedPanelState.isPanelDisplayed = true
                }

                return .none

            case .discardPanelContent:
                return .run { send in
                    let fileURL = xcodeInspector.activeDocumentURL
                    if let provider = await fetchPromptToCodeProvider(fileURL: fileURL) {
                        await send(.presentPanelContent(
                            .promptToCode(provider),
                            shouldDisplay: false
                        ))
                    } else if let provider = await fetchSuggestionProvider(fileURL: fileURL) {
                        await send(.presentPanelContent(
                            .suggestion(provider),
                            shouldDisplay: false
                        ))
                    } else {
                        await send(.removeDisplayedContent)
                    }
                }.animation(.easeInOut(duration: 0.2))

            case .switchToAnotherEditorAndUpdateContent:
                return .run { send in
                    let fileURL = xcodeInspector.activeDocumentURL
                    if let provider = await fetchPromptToCodeProvider(fileURL: fileURL) {
                        await send(.presentPanelContent(
                            .promptToCode(provider),
                            shouldDisplay: false
                        ))
                    } else if let provider = await fetchSuggestionProvider(fileURL: fileURL) {
                        await send(.presentPanelContent(
                            .suggestion(provider),
                            shouldDisplay: false
                        ))
                    } else {
                        await send(.removeDisplayedContent)
                    }
                }

            case .removeDisplayedContent:
                state.content = nil
                return .none

            case .sharedPanel:
                return .none
            case .suggestionPanel:
                return .none
            }
        }
    }

    func fetchSuggestionProvider(fileURL: URL) async -> SuggestionProvider? {
        guard let provider = await suggestionWidgetControllerDependency
            .suggestionWidgetDataSource?
            .suggestionForFile(at: fileURL) else { return nil }
        return provider
    }

    func fetchPromptToCodeProvider(fileURL: URL) async -> PromptToCodeProvider? {
        guard let provider = await suggestionWidgetControllerDependency
            .suggestionWidgetDataSource?
            .promptToCodeForFile(at: fileURL) else { return nil }
        return provider
    }
}


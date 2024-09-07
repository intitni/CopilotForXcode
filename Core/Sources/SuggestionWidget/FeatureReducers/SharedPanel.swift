import ComposableArchitecture
import Preferences
import SwiftUI

@Reducer
public struct SharedPanel {
    public struct Content {
        public var promptToCodeGroup = PromptToCodeGroup.State()
        var suggestion: PresentingCodeSuggestion?
        public var promptToCode: PromptToCodePanel.State? { promptToCodeGroup.activePromptToCode }
        var error: String?
    }

    @ObservableState
    public struct State {
        var content: Content = .init()
        var colorScheme: ColorScheme = .light
        var alignTopToAnchor = false
        var isPanelDisplayed: Bool = false
        var isEmpty: Bool {
            if content.error != nil { return false }
            if content.promptToCode != nil { return false }
            if content.suggestion != nil,
               UserDefaults.shared
               .value(for: \.suggestionPresentationMode) == .floatingWidget { return false }
            return true
        }

        var opacity: Double {
            guard isPanelDisplayed else { return 0 }
            guard !isEmpty else { return 0 }
            return 1
        }
    }

    public enum Action {
        case errorMessageCloseButtonTapped
        case promptToCodeGroup(PromptToCodeGroup.Action)
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.content.promptToCodeGroup, action: \.promptToCodeGroup) {
            PromptToCodeGroup()
        }

        Reduce { state, action in
            switch action {
            case .errorMessageCloseButtonTapped:
                state.content.error = nil
                return .none
            case .promptToCodeGroup:
                return .none
            }
        }
    }
}


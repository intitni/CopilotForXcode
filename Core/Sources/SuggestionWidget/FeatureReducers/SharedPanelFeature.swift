import ComposableArchitecture
import Preferences
import SwiftUI

public struct SharedPanelFeature: ReducerProtocol {
    public struct Content: Equatable {
        public var promptToCodeGroup = PromptToCodeGroup.State()
        var suggestion: CodeSuggestionProvider?
        public var promptToCode: PromptToCode.State? { promptToCodeGroup.activePromptToCode }
        var error: String?
    }

    public struct State: Equatable {
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

    public enum Action: Equatable {
        case errorMessageCloseButtonTapped
        case promptToCodeGroup(PromptToCodeGroup.Action)
    }

    public var body: some ReducerProtocol<State, Action> {
        Scope(state: \.content.promptToCodeGroup, action: /Action.promptToCodeGroup) {
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


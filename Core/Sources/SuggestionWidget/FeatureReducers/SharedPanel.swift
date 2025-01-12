import ComposableArchitecture
import Preferences
import SwiftUI

@Reducer
public struct SharedPanel {
    public struct Content {
        public var promptToCodeGroup = PromptToCodeGroup.State()
        public var promptToCode: PromptToCodePanel.State? { promptToCodeGroup.activePromptToCode }
    }

    @ObservableState
    public struct State {
        var content: Content = .init()
        var colorScheme: ColorScheme = .light
        var alignTopToAnchor = false
        var isPanelDisplayed: Bool = false
        var isEmpty: Bool { content.promptToCode != nil }

        var opacity: Double {
            guard isPanelDisplayed else { return 0 }
            guard !isEmpty else { return 0 }
            return 1
        }
    }

    public enum Action {
        case promptToCodeGroup(PromptToCodeGroup.Action)
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.content.promptToCodeGroup, action: \.promptToCodeGroup) {
            PromptToCodeGroup()
        }

        Reduce { state, action in
            switch action {
            case .promptToCodeGroup:
                return .none
            }
        }
    }
}


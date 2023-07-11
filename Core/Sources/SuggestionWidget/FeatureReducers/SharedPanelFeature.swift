import ComposableArchitecture
import Environment
import Preferences
import SwiftUI

public struct SharedPanelFeature: ReducerProtocol {
    public enum Content: Equatable {
        case suggestion(SuggestionProvider)
        case promptToCode(PromptToCodeProvider)
        case error(String)

        var contentHash: String {
            switch self {
            case let .error(e):
                return "error: \(e)"
            case let .suggestion(provider):
                return "suggestion: \(provider.code.hashValue)"
            case let .promptToCode(provider):
                return "provider: \(provider.id)"
            }
        }

        public static func == (lhs: Content, rhs: Content) -> Bool {
            lhs.contentHash == rhs.contentHash
        }
    }

    public struct State: Equatable {
        var content: Content?
        var colorScheme: ColorScheme = .light
        var alignTopToAnchor = false
        var isPanelDisplayed: Bool = false
        var opacity: Double {
            guard isPanelDisplayed else { return 0 }
            guard content != nil else { return 0 }
            return 1
        }
    }

    public enum Action: Equatable {
        case closeButtonTapped
    }

    public var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .closeButtonTapped:
                state.content = nil
                state.isPanelDisplayed = false
                return .none
            }
        }
    }
}

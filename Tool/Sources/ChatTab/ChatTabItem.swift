import ComposableArchitecture
import Foundation

public struct AnyChatTabBuilder: Equatable {
    public static func == (lhs: AnyChatTabBuilder, rhs: AnyChatTabBuilder) -> Bool {
        true
    }

    public let chatTabBuilder: any ChatTabBuilder

    public init(_ chatTabBuilder: any ChatTabBuilder) {
        self.chatTabBuilder = chatTabBuilder
    }
}

public struct ChatTabItem: ReducerProtocol {
    public typealias State = ChatTabInfo

    public enum Action: Equatable {
        case updateTitle(String)
        case openNewTab(AnyChatTabBuilder)
        case tabContentUpdated
        case close
        case focus
    }

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case let .updateTitle(title):
                state.title = title
                return .none
            case .openNewTab:
                return .none
            case .tabContentUpdated:
                return .none
            case .close:
                return .none
            case .focus:
                state.focusTrigger += 1
                return .none
            }
        }
    }
}


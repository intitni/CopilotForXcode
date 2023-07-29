import Foundation
import ComposableArchitecture

struct HostApp: ReducerProtocol {
    struct State: Equatable {
        var general = General.State()
    }
    
    enum Action: Equatable {
        case appear
        case general(General.Action)
    }
    
    var body: some ReducerProtocol<State, Action> {
        Scope(state: \.general, action: /Action.general) {
            General()
        }
        
        Reduce { _, action in
            switch action {
            case .appear:
                return .none
            case .general:
                return .none
            }
        }
    }
}

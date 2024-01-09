import ComposableArchitecture
import Preferences
import SwiftUI
import Toast

public struct ToastPanel: ReducerProtocol {
    public struct State: Equatable {
        var toast: Toast.State = .init()
        var colorScheme: ColorScheme = .light
        var alignTopToAnchor = false
    }
    
    public enum Action: Equatable {
        case start
        case toast(Toast.Action)
    }
    
    public var body: some ReducerProtocol<State, Action> {
        Scope(state: \.toast, action: /Action.toast) {
            Toast()
        }
        
        Reduce { state, action in
            switch action {
            case .start:
                return .run { send in
                    await send(.toast(.start))
                }
            case .toast:
                return .none
            }
        }
    }
}

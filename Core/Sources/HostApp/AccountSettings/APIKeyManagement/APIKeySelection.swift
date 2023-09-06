import Foundation
import SwiftUI
import ComposableArchitecture

struct APIKeySelection: ReducerProtocol {
    struct State: Equatable {
        @BindingState var apiKeyName: String = ""
        var availableAPIKeyNames: [String] {
            apiKeyManagement.availableAPIKeyNames
        }
        var apiKeyManagement: APIKeyManagement.State = .init()
        @BindingState var isAPIKeyManagementPresented: Bool = false
    }
    
    enum Action: Equatable, BindableAction {
        case appear
        case manageAPIKeysButtonClicked
        
        case binding(BindingAction<State>)
        case apiKeyManagement(APIKeyManagement.Action)
    }
    
    @Dependency(\.toast) var toast
    @Dependency(\.apiKeyKeychain) var keychain
    
    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        
        Scope(state: \.apiKeyManagement, action: /Action.apiKeyManagement) {
            APIKeyManagement()
        }
        
        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in
                    await send(.apiKeyManagement(.refreshAvailableAPIKeyNames))
                }
           
            case .manageAPIKeysButtonClicked:
                state.isAPIKeyManagementPresented = true
                return .none
                
            case .binding:
                return .none

            case .apiKeyManagement(.closeButtonClicked):
                state.isAPIKeyManagementPresented = false
                return .none
                
            case .apiKeyManagement:
                return .none
            }
        }
    }
}

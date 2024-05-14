import Foundation
import SwiftUI
import ComposableArchitecture

@Reducer
struct APIKeySelection {
    @ObservableState
    struct State: Equatable {
        var apiKeyName: String = ""
        var availableAPIKeyNames: [String] {
            apiKeyManagement.availableAPIKeyNames
        }
        var apiKeyManagement: APIKeyManagement.State = .init()
        var isAPIKeyManagementPresented: Bool = false
    }
    
    enum Action: Equatable, BindableAction {
        case appear
        case manageAPIKeysButtonClicked
        
        case binding(BindingAction<State>)
        case apiKeyManagement(APIKeyManagement.Action)
    }
    
    @Dependency(\.toast) var toast
    @Dependency(\.apiKeyKeychain) var keychain
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Scope(state: \.apiKeyManagement, action: \.apiKeyManagement) {
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

import ComposableArchitecture
import Foundation

struct APIKeySubmission: ReducerProtocol {
    struct State: Equatable {
        @BindingState var name: String = ""
        @BindingState var key: String = ""
    }
    
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveButtonClicked
        case cancelButtonClicked
    }
    
    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .saveButtonClicked:
                return .none
                
            case .cancelButtonClicked:
                return .none
                
            case .binding:
                return .none
            }
        }
    }
}

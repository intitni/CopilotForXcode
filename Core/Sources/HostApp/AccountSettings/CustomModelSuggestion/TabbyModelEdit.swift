import AIModel
import ComposableArchitecture
import Foundation
import Preferences
import Toast

@Reducer
struct TabbyModelEdit {
    @ObservableState
    struct State: Equatable {
        var apiKeyName: String { apiKeySelection.apiKeyName }
        var url: String { urlSelection.baseURL }
        var apiKeySelection: APIKeySelection.State = .init()
        var urlSelection: BaseURLSelection.State = .init()
        var authorizationMode: TabbyModel.AuthorizationMode
        var authorizationHeaderName: String
        var username: String
        var didSave = false
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case appear
        case saveButtonClicked
        case readCustomModelFromDisk
        case apiKeySelection(APIKeySelection.Action)
        case urlSelection(BaseURLSelection.Action)
    }

    @Dependency(\.toast) var toast
    @Dependency(\.userDefaults) var userDefaults

    var body: some Reducer<State, Action> {
        BindingReducer()

        Scope(state: \.apiKeySelection, action: \.apiKeySelection) {
            APIKeySelection()
        }

        Scope(state: \.urlSelection, action: \.urlSelection) {
            BaseURLSelection()
        }

        Reduce { state, action in
            switch action {
            case .appear:
                state.didSave = false
                return .run { send in
                    await send(.readCustomModelFromDisk)
                }

            case .saveButtonClicked:
                let urlString = state.url.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
                    toast("URL is invalid", .error)
                    return .none
                }
                userDefaults.set(TabbyModel(state: state), for: \.customSuggestionTabbyModel)
                state.didSave = true
                return .none

            case .readCustomModelFromDisk:
                let model = userDefaults.value(for: \.customSuggestionTabbyModel)
                state.apiKeySelection.apiKeyName = model.apiKeyName
                state.urlSelection.baseURL = model.url
                state.authorizationMode = model.authorizationMode
                state.authorizationHeaderName = model.authorizationHeaderName
                state.username = model.username
                return .none

            case .apiKeySelection:
                return .none

            case .urlSelection:
                return .none

            case .binding:
                return .none
            }
        }
    }

}

extension TabbyModel {
    func toState() -> TabbyModelEdit.State {
        .init(
            apiKeySelection: .init(
                apiKeyName: apiKeyName,
                apiKeyManagement: .init(availableAPIKeyNames: [apiKeyName])
            ),
            urlSelection: .init(baseURL: url),
            authorizationMode: authorizationMode,
            authorizationHeaderName: authorizationHeaderName,
            username: username
        )
    }

    init(state: TabbyModelEdit.State) {
        self = .init(
            url: state.urlSelection.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            authorizationMode: state.authorizationMode,
            apiKeyName: state.apiKeySelection.apiKeyName,
            authorizationHeaderName: state.authorizationHeaderName,
            username: state.username
        )
    }
}

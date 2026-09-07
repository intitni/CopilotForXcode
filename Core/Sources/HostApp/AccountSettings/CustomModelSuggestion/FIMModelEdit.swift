import AIModel
import ComposableArchitecture
import CustomSuggestionService
import Preferences
import Dependencies
import SwiftUI

@Reducer
struct FIMModelEdit {
    @ObservableState
    struct State: Equatable, Identifiable {
        var id: String = "Custom"
        var format: FIMModel.Format
        var maxTokens: Int = 4000
        var modelName: String = ""
        var apiKeyName: String { apiKeySelection.apiKeyName }
        var baseURL: String { baseURLSelection.baseURL }
        var availableModelNames: [String] = []
        var availableAPIKeys: [String] = []
        var suggestedMaxTokens: Int?
        var apiKeySelection: APIKeySelection.State = .init()
        var baseURLSelection: BaseURLSelection.State = .init()
        var ollamaKeepAlive: String = ""
        var authenticationMode: FIMModel.Info.AuthenticationMode = .bearerToken
        var authenticationHeaderFieldName: String = ""
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case appear
        case saveButtonClicked
        case refreshAvailableModelNames
        case checkSuggestedMaxTokens
        case readCustomModelFromDisk
        case apiKeySelection(APIKeySelection.Action)
        case baseURLSelection(BaseURLSelection.Action)
    }

    @Dependency(\.toast) var toast
    @Dependency(\.apiKeyKeychain) var keychain

    enum DebounceID: Hashable {
        case save
    }

    var body: some Reducer<State, Action> {
        BindingReducer()

        Scope(state: \.apiKeySelection, action: \.apiKeySelection) {
            APIKeySelection()
        }

        Scope(state: \.baseURLSelection, action: \.baseURLSelection) {
            BaseURLSelection()
        }

        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in
                    await send(.readCustomModelFromDisk)
                }

            case .saveButtonClicked:
                let model = FIMModel(state: state)
                return .run { _ in
                    UserDefaults.shared.set(model, for: \.customSuggestionFIMModel)
                }

            case .refreshAvailableModelNames:
                if state.format == .mistral {
                    state.availableModelNames = [
                        "codestral-latest",
                        "codestral-2405",
                    ]
                }

                return .none

            case .readCustomModelFromDisk:
                let model = UserDefaults.shared.value(for: \.customSuggestionFIMModel)
                state = model.toState()

                return .run { send in
                    await send(.checkSuggestedMaxTokens)
                    await send(.refreshAvailableModelNames)
                }

            case .checkSuggestedMaxTokens:
                switch state.format {
                case .mistral:
                    return .none
                default:
                    state.suggestedMaxTokens = nil
                    return .none
                }

            case .apiKeySelection:
                return .none

            case .baseURLSelection:
                return .none

            case .binding(\.format):
                return .run { send in
                    await send(.refreshAvailableModelNames)
                    await send(.checkSuggestedMaxTokens)
                }

            case .binding(\.modelName):
                return .run { send in
                    await send(.checkSuggestedMaxTokens)
                }

            case .binding:
                return .none
            }
        }
    }

}

extension FIMModel {
    func toState() -> FIMModelEdit.State {
        .init(
            id: id,
            format: format,
            maxTokens: info.maxTokens,
            modelName: info.modelName,
            apiKeySelection: .init(
                apiKeyName: info.apiKeyName,
                apiKeyManagement: .init(availableAPIKeyNames: [info.apiKeyName])
            ),
            baseURLSelection: .init(baseURL: info.baseURL, isFullURL: info.isFullURL),
            ollamaKeepAlive: info.ollamaInfo.keepAlive,
            authenticationMode: info.authenticationMode,
            authenticationHeaderFieldName: info.authenticationHeaderFieldName
        )
    }

    init(state: FIMModelEdit.State) {
        self.init(
            id: state.id,
            name: "Custom Model (Completion API)",
            format: state.format,
            info: .init(
                apiKeyName: state.apiKeyName,
                baseURL: state.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                isFullURL: state.baseURLSelection.isFullURL,
                maxTokens: state.maxTokens,
                modelName: state.modelName.trimmingCharacters(in: .whitespacesAndNewlines),
                authenticationMode: state.authenticationMode,
                authenticationHeaderFieldName: state.authenticationHeaderFieldName,
                ollamaInfo: .init(keepAlive: state.ollamaKeepAlive)
            )
        )
    }
}


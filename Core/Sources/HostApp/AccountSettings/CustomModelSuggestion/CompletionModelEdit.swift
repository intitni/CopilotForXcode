import AIModel
import ComposableArchitecture
import Preferences
import Toast

@Reducer
struct CompletionModelEdit {
    @ObservableState
    struct State: Equatable, Identifiable {
        var id: String = "Custom"
        var format: CompletionModel.Format
        var maxTokens: Int = 4000
        var modelName: String = ""
        var apiKeyName: String { apiKeySelection.apiKeyName }
        var baseURL: String { baseURLSelection.baseURL }
        var availableModelNames: [String] = []
        var suggestedMaxTokens: Int?
        var apiKeySelection: APIKeySelection.State = .init()
        var baseURLSelection: BaseURLSelection.State = .init()
        var ollamaKeepAlive: String = ""
        var didSave = false
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
    @Dependency(\.userDefaults) var userDefaults

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
                state.didSave = false
                return .run { send in
                    await send(.readCustomModelFromDisk)
                }

            case .saveButtonClicked:
                let modelName = state.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseURL = state.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !modelName.isEmpty else {
                    toast("Model name cannot be empty", .error)
                    return .none
                }
                guard !baseURL.isEmpty else {
                    toast("Base URL cannot be empty", .error)
                    return .none
                }
                userDefaults.set(CompletionModel(state: state), for: \.customSuggestionCompletionModel)
                state.didSave = true
                return .none

            case .refreshAvailableModelNames:
                if state.format == .openAI {
                    state.availableModelNames = KnownCompletionModels.allCases.map(\.rawValue)
                }

                return .none

            case .readCustomModelFromDisk:
                let model = userDefaults.value(for: \.customSuggestionCompletionModel)
                state.id = model.id
                state.format = model.format
                state.maxTokens = model.info.maxTokens
                state.modelName = model.info.modelName
                state.apiKeySelection.apiKeyName = model.info.apiKeyName
                state.baseURLSelection.baseURL = model.info.baseURL
                state.baseURLSelection.isFullURL = model.info.isFullURL
                state.ollamaKeepAlive = model.info.ollamaInfo.keepAlive

                return .run { send in
                    await send(.checkSuggestedMaxTokens)
                    await send(.refreshAvailableModelNames)
                }

            case .checkSuggestedMaxTokens:
                switch state.format {
                case .openAI:
                    if let knownModel = KnownCompletionModels(rawValue: state.modelName) {
                        state.suggestedMaxTokens = knownModel.maxToken
                    } else {
                        state.suggestedMaxTokens = nil
                    }
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

extension CompletionModel {
    func toState() -> CompletionModelEdit.State {
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
            ollamaKeepAlive: info.ollamaInfo.keepAlive
        )
    }

    init(state: CompletionModelEdit.State) {
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
                ollamaInfo: .init(keepAlive: state.ollamaKeepAlive)
            )
        )
    }
}

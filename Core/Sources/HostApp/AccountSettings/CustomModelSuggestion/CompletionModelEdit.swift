import AIModel
import ComposableArchitecture
import CustomSuggestionService
import Preferences
import Dependencies
import SwiftUI

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
        var availableAPIKeys: [String] = []
        var suggestedMaxTokens: Int?
        var apiKeySelection: APIKeySelection.State = .init()
        var baseURLSelection: BaseURLSelection.State = .init()
        var ollamaKeepAlive: String = ""
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
                let model = CompletionModel(state: state)
                return .run { _ in
                    UserDefaults.shared.set(model, for: \.customSuggestionCompletionModel)
                }

            case .refreshAvailableModelNames:
                if state.format == .openAI {
                    state.availableModelNames = CustomSuggestionService.OpenAIService.ChatCompletionModels.allCases
                        .map(\.rawValue)
                }

                return .none

            case .readCustomModelFromDisk:
                let model = UserDefaults.shared.value(for: \.customSuggestionCompletionModel)
                state = model.toState()

                return .run { send in
                    await send(.checkSuggestedMaxTokens)
                    await send(.refreshAvailableModelNames)
                }

            case .checkSuggestedMaxTokens:
                switch state.format {
                case .openAI:
                    if let knownModel = CustomSuggestionService.OpenAIService.CompletionModels(rawValue: state.modelName) {
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


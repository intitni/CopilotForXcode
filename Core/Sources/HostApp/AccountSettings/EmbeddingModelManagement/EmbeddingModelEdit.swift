import AIModel
import ComposableArchitecture
import Dependencies
import Keychain
import OpenAIService
import Preferences
import SwiftUI
import Toast

@Reducer
struct EmbeddingModelEdit {
    @ObservableState
    struct State: Equatable, Identifiable {
        var id: String
        var name: String
        var format: EmbeddingModel.Format
        var maxTokens: Int = 8191
        var modelName: String = ""
        var ollamaKeepAlive: String = ""
        var apiKeyName: String { apiKeySelection.apiKeyName }
        var baseURL: String { baseURLSelection.baseURL }
        var isFullURL: Bool { baseURLSelection.isFullURL }
        var availableModelNames: [String] = []
        var availableAPIKeys: [String] = []
        var isTesting = false
        var suggestedMaxTokens: Int?
        var apiKeySelection: APIKeySelection.State = .init()
        var baseURLSelection: BaseURLSelection.State = .init()
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case appear
        case saveButtonClicked
        case cancelButtonClicked
        case refreshAvailableModelNames
        case testButtonClicked
        case testSucceeded(String)
        case testFailed(String)
        case checkSuggestedMaxTokens
        case apiKeySelection(APIKeySelection.Action)
        case baseURLSelection(BaseURLSelection.Action)
    }

    var toast: (String, ToastType) -> Void {
        @Dependency(\.namespacedToast) var toast
        return {
            toast($0, $1, "EmbeddingModelEdit")
        }
    }

    @Dependency(\.apiKeyKeychain) var keychain

    var body: some ReducerOf<Self> {
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
                    await send(.refreshAvailableModelNames)
                    await send(.checkSuggestedMaxTokens)
                }

            case .saveButtonClicked:
                return .none

            case .cancelButtonClicked:
                return .none

            case .testButtonClicked:
                guard !state.isTesting else { return .none }
                state.isTesting = true
                let model = EmbeddingModel(
                    id: state.id,
                    name: state.name,
                    format: state.format,
                    info: .init(
                        apiKeyName: state.apiKeyName,
                        baseURL: state.baseURL,
                        isFullURL: state.isFullURL,
                        maxTokens: state.maxTokens,
                        modelName: state.modelName
                    )
                )
                return .run { send in
                    do {
                        _ = try await EmbeddingService(
                            configuration: UserPreferenceEmbeddingConfiguration()
                                .overriding {
                                    $0.model = model
                                }
                        ).embed(text: "Hello")
                        await send(.testSucceeded("Succeeded!"))
                    } catch {
                        await send(.testFailed(error.localizedDescription))
                    }
                }

            case let .testSucceeded(message):
                state.isTesting = false
                toast(message, .info)
                return .none

            case let .testFailed(message):
                state.isTesting = false
                toast(message, .error)
                return .none

            case .refreshAvailableModelNames:
                if state.format == .openAI {
                    state.availableModelNames = ChatGPTModel.allCases.map(\.rawValue)
                }

                return .none

            case .checkSuggestedMaxTokens:
                guard state.format == .openAI,
                      let knownModel = OpenAIEmbeddingModel(rawValue: state.modelName)
                else {
                    state.suggestedMaxTokens = nil
                    return .none
                }
                state.suggestedMaxTokens = knownModel.maxToken
                return .none

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

extension EmbeddingModel {
    init(state: EmbeddingModelEdit.State) {
        self.init(
            id: state.id,
            name: state.name,
            format: state.format,
            info: .init(
                apiKeyName: state.apiKeyName,
                baseURL: state.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                isFullURL: state.isFullURL,
                maxTokens: state.maxTokens,
                modelName: state.modelName.trimmingCharacters(in: .whitespacesAndNewlines),
                ollamaInfo: .init(keepAlive: state.ollamaKeepAlive)
            )
        )
    }

    func toState() -> EmbeddingModelEdit.State {
        .init(
            id: id,
            name: name,
            format: format,
            maxTokens: info.maxTokens,
            modelName: info.modelName,
            ollamaKeepAlive: info.ollamaInfo.keepAlive,
            apiKeySelection: .init(
                apiKeyName: info.apiKeyName,
                apiKeyManagement: .init(availableAPIKeyNames: [info.apiKeyName])
            ),
            baseURLSelection: .init(
                baseURL: info.baseURL,
                isFullURL: info.isFullURL
            )
        )
    }
}


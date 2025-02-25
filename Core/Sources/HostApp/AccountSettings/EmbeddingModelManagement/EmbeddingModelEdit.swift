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
        var dimensions: Int = 1536
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
        var customHeaders: [ChatModel.Info.CustomHeaderInfo.HeaderField] = []
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
        case fixDimensions(Int)
        case checkSuggestedMaxTokens
        case selectModelFormat(ModelFormat)
        case apiKeySelection(APIKeySelection.Action)
        case baseURLSelection(BaseURLSelection.Action)
    }
    
    enum ModelFormat: CaseIterable {
        case openAI
        case azureOpenAI
        case ollama
        case gitHubCopilot
        case openAICompatible
        case mistralOpenAICompatible
        case voyageAIOpenAICompatible
        
        init(_ format: EmbeddingModel.Format) {
            switch format {
            case .openAI:
                self = .openAI
            case .azureOpenAI:
                self = .azureOpenAI
            case .ollama:
                self = .ollama
            case .openAICompatible:
                self = .openAICompatible
            case .gitHubCopilot:
                self = .gitHubCopilot
            }
        }
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
                let dimensions = state.dimensions
                let model = EmbeddingModel(
                    id: state.id,
                    name: state.name,
                    format: state.format,
                    info: .init(
                        apiKeyName: state.apiKeyName,
                        baseURL: state.baseURL,
                        isFullURL: state.isFullURL,
                        maxTokens: state.maxTokens,
                        dimensions: dimensions,
                        modelName: state.modelName
                    )
                )
                return .run { send in
                    do {
                        let result = try await EmbeddingService(
                            configuration: UserPreferenceEmbeddingConfiguration()
                                .overriding {
                                    $0.model = model
                                }
                        ).embed(text: "Hello")
                        if result.data.isEmpty {
                            await send(.testFailed("No data returned"))
                            return
                        }
                        let actualDimensions = result.data.first?.embedding.count ?? 0
                        if actualDimensions != dimensions {
                            await send(
                                .testFailed("Invalid dimension, should be \(actualDimensions)")
                            )
                            await send(.fixDimensions(actualDimensions))
                        } else {
                            await send(
                                .testSucceeded("Succeeded! (Dimensions: \(actualDimensions))")
                            )
                        }
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
                state.dimensions = knownModel.dimensions
                return .none

            case let .fixDimensions(value):
                state.dimensions = value
                return .none
                
            case let .selectModelFormat(format):
                switch format {
                case .openAI:
                    state.format = .openAI
                case .azureOpenAI:
                    state.format = .azureOpenAI
                case .ollama:
                    state.format = .ollama
                case .openAICompatible:
                    state.format = .openAICompatible
                case .gitHubCopilot:
                    state.format = .gitHubCopilot
                case .mistralOpenAICompatible:
                    state.format = .openAICompatible
                    state.baseURLSelection.baseURL = "https://api.mistral.ai"
                    state.baseURLSelection.isFullURL = false
                case .voyageAIOpenAICompatible:
                    state.format = .openAICompatible
                    state.baseURLSelection.baseURL = "https://api.voyage.ai"
                    state.baseURLSelection.isFullURL = false
                }
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
                dimensions: state.dimensions,
                modelName: state.modelName.trimmingCharacters(in: .whitespacesAndNewlines),
                ollamaInfo: .init(keepAlive: state.ollamaKeepAlive),
                customHeaderInfo: .init(headers: state.customHeaders)
            )
        )
    }

    func toState() -> EmbeddingModelEdit.State {
        .init(
            id: id,
            name: name,
            format: format,
            maxTokens: info.maxTokens,
            dimensions: info.dimensions,
            modelName: info.modelName,
            ollamaKeepAlive: info.ollamaInfo.keepAlive,
            apiKeySelection: .init(
                apiKeyName: info.apiKeyName,
                apiKeyManagement: .init(availableAPIKeyNames: [info.apiKeyName])
            ),
            baseURLSelection: .init(
                baseURL: info.baseURL,
                isFullURL: info.isFullURL
            ),
            customHeaders: info.customHeaderInfo.headers
        )
    }
}


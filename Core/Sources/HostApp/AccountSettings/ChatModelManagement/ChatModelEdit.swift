import AIModel
import ComposableArchitecture
import Dependencies
import Keychain
import OpenAIService
import Preferences
import SwiftUI
import Toast

struct ChatModelEdit: ReducerProtocol {
    struct State: Equatable, Identifiable {
        var id: String
        @BindingState var name: String
        @BindingState var format: ChatModel.Format
        @BindingState var maxTokens: Int = 4000
        @BindingState var supportsFunctionCalling: Bool = true
        @BindingState var modelName: String = ""
        @BindingState var ollamaKeepAlive: String = ""
        @BindingState var apiVersion: String = ""
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
            toast($0, $1, "ChatModelEdit")
        }
    }

    @Dependency(\.apiKeyKeychain) var keychain

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Scope(state: \.apiKeySelection, action: /Action.apiKeySelection) {
            APIKeySelection()
        }

        Scope(state: \.baseURLSelection, action: /Action.baseURLSelection) {
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
                let model = ChatModel(state: state)
                return .run { send in
                    do {
                        let service = ChatGPTService(
                            configuration: UserPreferenceChatGPTConfiguration()
                                .overriding {
                                    $0.model = model
                                }
                        )
                        let reply = try await service
                            .sendAndWait(content: "Respond with \"Test succeeded\"")
                        await send(.testSucceeded(reply ?? "No Message"))
                        let stream = try await service
                            .send(content: "Respond with \"Stream response is working\"")
                        var streamReply = ""
                        for try await chunk in stream {
                            streamReply += chunk
                        }
                        await send(.testSucceeded(streamReply))
                    } catch {
                        await send(.testFailed(error.localizedDescription))
                    }
                }

            case let .testSucceeded(message):
                state.isTesting = false
                toast(message.trimmingCharacters(in: .whitespacesAndNewlines), .info)
                return .none

            case let .testFailed(message):
                state.isTesting = false
                toast(message.trimmingCharacters(in: .whitespacesAndNewlines), .error)
                return .none

            case .refreshAvailableModelNames:
                if state.format == .openAI {
                    state.availableModelNames = ChatGPTModel.allCases.map(\.rawValue)
                }

                return .none

            case .checkSuggestedMaxTokens:
                switch state.format {
                case .openAI:
                    if let knownModel = ChatGPTModel(rawValue: state.modelName) {
                        state.suggestedMaxTokens = knownModel.maxToken
                    } else {
                        state.suggestedMaxTokens = nil
                    }
                    return .none
                case .googleAI:
                    if let knownModel = GoogleGenerativeAIModel(rawValue: state.modelName) {
                        state.suggestedMaxTokens = knownModel.maxToken
                    } else {
                        state.suggestedMaxTokens = nil
                    }
                    return .none
                case .claude:
                    if let knownModel = ClaudeChatCompletionsService
                        .KnownModel(rawValue: state.modelName)
                    {
                        state.suggestedMaxTokens = knownModel.contextWindow
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

            case .binding(\.$format):
                return .run { send in
                    await send(.refreshAvailableModelNames)
                    await send(.checkSuggestedMaxTokens)
                }

            case .binding(\.$modelName):
                return .run { send in
                    await send(.checkSuggestedMaxTokens)
                }

            case .binding:
                return .none
            }
        }
    }
}

extension ChatModelEdit.State {
    init(model: ChatModel) {
        self.init(
            id: model.id,
            name: model.name,
            format: model.format,
            maxTokens: model.info.maxTokens,
            supportsFunctionCalling: model.info.supportsFunctionCalling,
            modelName: model.info.modelName,
            ollamaKeepAlive: model.info.ollamaInfo.keepAlive,
            apiVersion: model.info.googleGenerativeAIInfo.apiVersion,
            apiKeySelection: .init(
                apiKeyName: model.info.apiKeyName,
                apiKeyManagement: .init(availableAPIKeyNames: [model.info.apiKeyName])
            ),
            baseURLSelection: .init(baseURL: model.info.baseURL, isFullURL: model.info.isFullURL)
        )
    }
}

extension ChatModel {
    init(state: ChatModelEdit.State) {
        self.init(
            id: state.id,
            name: state.name,
            format: state.format,
            info: .init(
                apiKeyName: state.apiKeyName,
                baseURL: state.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                isFullURL: state.isFullURL,
                maxTokens: state.maxTokens,
                supportsFunctionCalling: {
                    switch state.format {
                    case .googleAI, .ollama, .claude:
                        return false
                    case .azureOpenAI, .openAI, .openAICompatible:
                        return state.supportsFunctionCalling
                    }
                }(),
                modelName: state.modelName.trimmingCharacters(in: .whitespacesAndNewlines),
                ollamaInfo: .init(keepAlive: state.ollamaKeepAlive),
                googleGenerativeAIInfo: .init(apiVersion: state.apiVersion)
            )
        )
    }
}


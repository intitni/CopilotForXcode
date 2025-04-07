import AIModel
import ComposableArchitecture
import Dependencies
import Keychain
import OpenAIService
import Preferences
import SwiftUI
import Toast

@Reducer
struct ChatModelEdit {
    @ObservableState
    struct State: Equatable, Identifiable {
        var id: String
        var name: String
        var format: ChatModel.Format
        var maxTokens: Int = 4000
        var supportsFunctionCalling: Bool = true
        var modelName: String = ""
        var ollamaKeepAlive: String = ""
        var apiVersion: String = ""
        var apiKeyName: String { apiKeySelection.apiKeyName }
        var baseURL: String { baseURLSelection.baseURL }
        var isFullURL: Bool { baseURLSelection.isFullURL }
        var availableModelNames: [String] = []
        var availableAPIKeys: [String] = []
        var isTesting = false
        var suggestedMaxTokens: Int?
        var apiKeySelection: APIKeySelection.State = .init()
        var baseURLSelection: BaseURLSelection.State = .init()
        var enforceMessageOrder: Bool = false
        var openAIOrganizationID: String = ""
        var openAIProjectID: String = ""
        var customHeaders: [ChatModel.Info.CustomHeaderInfo.HeaderField] = []
        var openAICompatibleSupportsMultipartMessageContent = true
        var requiresBeginWithUserMessage = false
        var customBody: String = ""
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
        case selectModelFormat(ModelFormat)
        case apiKeySelection(APIKeySelection.Action)
        case baseURLSelection(BaseURLSelection.Action)
    }

    enum ModelFormat: CaseIterable {
        case openAI
        case azureOpenAI
        case googleAI
        case ollama
        case claude
        case gitHubCopilot
        case openAICompatible
        case deepSeekOpenAICompatible
        case openRouterOpenAICompatible
        case grokOpenAICompatible
        case mistralOpenAICompatible

        init(_ format: ChatModel.Format) {
            switch format {
            case .openAI:
                self = .openAI
            case .azureOpenAI:
                self = .azureOpenAI
            case .googleAI:
                self = .googleAI
            case .ollama:
                self = .ollama
            case .claude:
                self = .claude
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
            toast($0, $1, "ChatModelEdit")
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
                let model = ChatModel(state: state)
                return .run { send in
                    do {
                        let configuration = UserPreferenceChatGPTConfiguration().overriding {
                            $0.model = model
                        }
                        let service = ChatGPTService(configuration: configuration)
                        let stream = service.send(TemplateChatGPTMemory(
                            memoryTemplate: .init(messages: [
                                .init(chatMessage: .init(
                                    role: .system,
                                    content: "You are a bot. Just do what is told."
                                )),
                                .init(chatMessage: .init(
                                    role: .assistant,
                                    content: "Hello"
                                )),
                                .init(chatMessage: .init(
                                    role: .user,
                                    content: "Respond with \"Test succeeded.\""
                                )),
                                .init(chatMessage: .init(
                                    role: .user,
                                    content: "Respond with \"Test succeeded.\""
                                )),
                            ]),
                            configuration: configuration,
                            functionProvider: NoChatGPTFunctionProvider()
                        ))
                        let streamReply = try await stream.asText()
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
                case .gitHubCopilot:
                    if let knownModel = AvailableGitHubCopilotModel(rawValue: state.modelName) {
                        state.suggestedMaxTokens = knownModel.contextWindow
                    } else {
                        state.suggestedMaxTokens = nil
                    }
                    return .none
                default:
                    state.suggestedMaxTokens = nil
                    return .none
                }

            case let .selectModelFormat(format):
                switch format {
                case .openAI:
                    state.format = .openAI
                case .azureOpenAI:
                    state.format = .azureOpenAI
                case .googleAI:
                    state.format = .googleAI
                case .ollama:
                    state.format = .ollama
                case .claude:
                    state.format = .claude
                case .gitHubCopilot:
                    state.format = .gitHubCopilot
                case .openAICompatible:
                    state.format = .openAICompatible
                case .deepSeekOpenAICompatible:
                    state.format = .openAICompatible
                    state.baseURLSelection.baseURL = "https://api.deepseek.com"
                    state.baseURLSelection.isFullURL = false
                case .openRouterOpenAICompatible:
                    state.format = .openAICompatible
                    state.baseURLSelection.baseURL = "https://openrouter.ai"
                    state.baseURLSelection.isFullURL = false
                case .grokOpenAICompatible:
                    state.format = .openAICompatible
                    state.baseURLSelection.baseURL = "https://api.x.ai"
                    state.baseURLSelection.isFullURL = false
                case .mistralOpenAICompatible:
                    state.format = .openAICompatible
                    state.baseURLSelection.baseURL = "https://api.mistral.ai"
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
                    case .azureOpenAI, .openAI, .openAICompatible, .gitHubCopilot:
                        return state.supportsFunctionCalling
                    }
                }(),
                modelName: state.modelName.trimmingCharacters(in: .whitespacesAndNewlines),
                openAIInfo: .init(
                    organizationID: state.openAIOrganizationID,
                    projectID: state.openAIProjectID
                ),
                ollamaInfo: .init(keepAlive: state.ollamaKeepAlive),
                googleGenerativeAIInfo: .init(apiVersion: state.apiVersion),
                openAICompatibleInfo: .init(
                    enforceMessageOrder: state.enforceMessageOrder,
                    supportsMultipartMessageContent: state
                        .openAICompatibleSupportsMultipartMessageContent,
                    requiresBeginWithUserMessage: state.requiresBeginWithUserMessage
                ),
                customHeaderInfo: .init(headers: state.customHeaders),
                customBodyInfo: .init(jsonBody: state.customBody)
            )
        )
    }

    func toState() -> ChatModelEdit.State {
        .init(
            id: id,
            name: name,
            format: format,
            maxTokens: info.maxTokens,
            supportsFunctionCalling: info.supportsFunctionCalling,
            modelName: info.modelName,
            ollamaKeepAlive: info.ollamaInfo.keepAlive,
            apiVersion: info.googleGenerativeAIInfo.apiVersion,
            apiKeySelection: .init(
                apiKeyName: info.apiKeyName,
                apiKeyManagement: .init(availableAPIKeyNames: [info.apiKeyName])
            ),
            baseURLSelection: .init(baseURL: info.baseURL, isFullURL: info.isFullURL),
            enforceMessageOrder: info.openAICompatibleInfo.enforceMessageOrder,
            openAIOrganizationID: info.openAIInfo.organizationID,
            openAIProjectID: info.openAIInfo.projectID,
            customHeaders: info.customHeaderInfo.headers,
            openAICompatibleSupportsMultipartMessageContent: info.openAICompatibleInfo
                .supportsMultipartMessageContent,
            requiresBeginWithUserMessage: info.openAICompatibleInfo.requiresBeginWithUserMessage,
            customBody: info.customBodyInfo.jsonBody
        )
    }
}


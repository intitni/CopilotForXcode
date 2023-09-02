import AIModel
import ComposableArchitecture
import Dependencies
import Keychain
import OpenAIService
import Preferences
import SwiftUI

struct APIKeyKeychainDependencyKey: DependencyKey {
    static var liveValue: KeychainType = Keychain.apiKey
    static var previewValue: KeychainType = FakeKeyChain()
    static var testValue: KeychainType = FakeKeyChain()
}

extension DependencyValues {
    var apiKeyKeychain: KeychainType {
        get { self[APIKeyKeychainDependencyKey.self] }
        set { self[APIKeyKeychainDependencyKey.self] = newValue }
    }
}

struct ChatModelEdit: ReducerProtocol {
    struct State: Equatable, Identifiable {
        var id: String
        @BindingState var name: String
        @BindingState var format: ChatModel.Format
        @BindingState var apiKeyName: String = ""
        @BindingState var baseURL: String = ""
        @BindingState var maxTokens: Int = 4000
        @BindingState var supportsFunctionCalling: Bool = true
        @BindingState var modelName: String = ""
        var availableModelNames: [String] = []
        var availableAPIKeys: [String] = []
        var isTesting = false
        var suggestedMaxTokens: Int?
        @PresentationState var apiKeySubmission: APIKeySubmission.State?
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case appear
        case saveButtonClicked
        case cancelButtonClicked
        case refreshAvailableModelNames
        case refreshAvailableAPIKeys
        case testButtonClicked
        case testSucceeded(String)
        case testFailed(String)
        case createAPIKeyButtonClicked
        case checkSuggestedMaxTokens
        case apiKeySubmission(PresentationAction<APIKeySubmission.Action>)
    }

    @Dependency(\.toast) var toast
    @Dependency(\.apiKeyKeychain) var keychain

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .appear:
                return .merge([
                    .run { await $0(.refreshAvailableAPIKeys) },
                    .run { await $0(.refreshAvailableModelNames) },
                    .run { await $0(.checkSuggestedMaxTokens) },
                ])

            case .saveButtonClicked:
                return .none

            case .cancelButtonClicked:
                return .none

            case .testButtonClicked:
                guard !state.isTesting else { return .none }
                state.isTesting = true
                let model = ChatModel(
                    id: state.id,
                    name: state.name,
                    format: state.format,
                    info: .init(
                        apiKeyName: state.apiKeyName,
                        baseURL: state.baseURL,
                        maxTokens: state.maxTokens,
                        supportsFunctionCalling: state.supportsFunctionCalling,
                        modelName: state.modelName
                    )
                )
                return .run { send in
                    do {
                        let reply =
                            try await ChatGPTService(
                                configuration: UserPreferenceChatGPTConfiguration()
                                    .overriding {
                                        $0.model = model
                                    }
                            ).sendAndWait(content: "Hello")
                        await send(.testSucceeded(reply ?? "No Message"))
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

            case .refreshAvailableAPIKeys:
                do {
                    let pairs = try keychain.getAll()
                    state.availableAPIKeys = Array(pairs.keys)
                } catch {
                    toast(error.localizedDescription, .error)
                }

                return .none

            case .createAPIKeyButtonClicked:
                state.apiKeySubmission = .init()
                return .none

            case .apiKeySubmission(.presented(.saveButtonClicked)):
                if let key = state.apiKeySubmission {
                    do {
                        try keychain.update(key.name, key: key.key)
                    } catch {
                        toast(error.localizedDescription, .error)
                    }
                }
                state.apiKeySubmission = nil
                return .none

            case .apiKeySubmission(.presented(.cancelButtonClicked)):
                state.apiKeySubmission = nil
                return .none

            case .apiKeySubmission:
                return .none

            case .checkSuggestedMaxTokens:
                guard state.format == .openAI,
                      let knownModel = ChatGPTModel(rawValue: state.modelName)
                else {
                    state.suggestedMaxTokens = nil
                    return .none
                }
                state.suggestedMaxTokens = knownModel.maxToken
                return .none

            case .binding(\.$format):
                return .merge([
                    .run { await $0(.refreshAvailableAPIKeys) },
                    .run { await $0(.refreshAvailableModelNames) },
                    .run { await $0(.checkSuggestedMaxTokens) },
                ])

            case .binding(\.$modelName):
                return .run { send in
                    await send(.checkSuggestedMaxTokens)
                }

            case .binding:
                return .none
            }
        }
        .ifLet(\.$apiKeySubmission, action: /Action.apiKeySubmission) {
            APIKeySubmission()
        }
    }
}

extension ChatModelEdit.State {
    init(model: ChatModel) {
        self.init(
            id: model.id,
            name: model.name,
            format: model.format,
            apiKeyName: model.info.apiKeyName,
            baseURL: model.info.baseURL,
            maxTokens: model.info.maxTokens,
            supportsFunctionCalling: model.info.supportsFunctionCalling,
            modelName: model.info.modelName
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
                baseURL: state.baseURL,
                maxTokens: state.maxTokens,
                supportsFunctionCalling: state.supportsFunctionCalling,
                modelName: state.modelName
            )
        )
    }
}


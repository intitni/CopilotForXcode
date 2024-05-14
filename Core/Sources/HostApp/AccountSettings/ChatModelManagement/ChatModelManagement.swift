import AIModel
import ComposableArchitecture
import Keychain
import Preferences
import SwiftUI

extension ChatModel: ManageableAIModel {
    var formatName: String {
        switch format {
        case .openAI: return "OpenAI"
        case .azureOpenAI: return "Azure OpenAI"
        case .openAICompatible: return "OpenAI Compatible"
        case .googleAI: return "Google Generative AI"
        case .ollama: return "Ollama"
        case .claude: return "Claude"
        }
    }

    @ViewBuilder
    var infoDescriptors: some View {
        Text(info.modelName)

        if !info.baseURL.isEmpty {
            Image(systemName: "line.diagonal")
            Text(info.baseURL)
        }

        Image(systemName: "line.diagonal")

        Text("\(info.maxTokens) tokens")

        Image(systemName: "line.diagonal")

        Text(
            "function calling \(info.supportsFunctionCalling ? Image(systemName: "checkmark.square") : Image(systemName: "xmark.square"))"
        )
    }
}

@Reducer
struct ChatModelManagement: AIModelManagement {
    typealias Model = ChatModel

    @ObservableState
    struct State: Equatable, AIModelManagementState {
        typealias Model = ChatModel
        var models: IdentifiedArrayOf<ChatModel> = []
        @Presents var editingModel: ChatModelEdit.State?
        var selectedModelId: String? { editingModel?.id }
    }

    enum Action: Equatable, AIModelManagementAction {
        typealias Model = ChatModel
        case appear
        case createModel
        case removeModel(id: Model.ID)
        case selectModel(id: Model.ID)
        case duplicateModel(id: Model.ID)
        case moveModel(from: IndexSet, to: Int)
        case chatModelItem(PresentationAction<ChatModelEdit.Action>)
    }

    @Dependency(\.toast) var toast
    @Dependency(\.userDefaults) var userDefaults

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appear:
                if isPreview { return .none }
                state.models = .init(
                    userDefaults.value(for: \.chatModels),
                    id: \.id,
                    uniquingIDsWith: { a, _ in a }
                )

                return .none

            case .createModel:
                state.editingModel = .init(
                    id: UUID().uuidString,
                    name: "New Model",
                    format: .openAI
                )
                return .none

            case let .removeModel(id):
                state.models.remove(id: id)
                persist(state)
                return .none

            case let .selectModel(id):
                guard let model = state.models[id: id] else { return .none }
                state.editingModel = model.toState()
                return .none

            case let .duplicateModel(id):
                guard var model = state.models[id: id] else { return .none }
                model.id = UUID().uuidString
                model.name += " (Copy)"

                if let index = state.models.index(id: id) {
                    state.models.insert(model, at: index + 1)
                } else {
                    state.models.append(model)
                }
                persist(state)
                return .none

            case let .moveModel(from, to):
                state.models.move(fromOffsets: from, toOffset: to)
                persist(state)
                return .none

            case .chatModelItem(.presented(.saveButtonClicked)):
                guard let editingModel = state.editingModel, validateModel(editingModel)
                else { return .none }

                if let index = state.models
                    .firstIndex(where: { $0.id == editingModel.id })
                {
                    state.models[index] = .init(state: editingModel)
                } else {
                    state.models.append(.init(state: editingModel))
                }
                persist(state)
                return .run { send in
                    await send(.chatModelItem(.dismiss))
                }

            case .chatModelItem(.presented(.cancelButtonClicked)):
                return .run { send in
                    await send(.chatModelItem(.dismiss))
                }

            case .chatModelItem:
                return .none
            }
        }.ifLet(\.$editingModel, action: \.chatModelItem) {
            ChatModelEdit()
        }
    }

    func persist(_ state: State) {
        let models = state.models
        userDefaults.set(Array(models), for: \.chatModels)
    }

    func validateModel(_ chatModel: ChatModelEdit.State) -> Bool {
        guard !chatModel.name.isEmpty else {
            toast("Model name cannot be empty", .error)
            return false
        }
        guard !chatModel.id.isEmpty else {
            toast("Model ID cannot be empty", .error)
            return false
        }

        guard !chatModel.modelName.isEmpty else {
            toast("Model name cannot be empty", .error)
            return false
        }
        return true
    }
}


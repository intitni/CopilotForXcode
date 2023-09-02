import AIModel
import ComposableArchitecture
import Keychain
import Preferences
import SwiftUI

struct ChatModelManagement: ReducerProtocol {
    struct State: Equatable {
        var models: IdentifiedArray<String, ChatModel>
        @PresentationState var editingModel: ChatModelEdit.State?
    }

    enum Action: Equatable {
        case appear
        case createModel
        case removeModel(id: String)
        case selectModel(id: String)
        case duplicateModel(id: String)
        case moveModel(from: IndexSet, to: Int)
        case chatModelItem(PresentationAction<ChatModelEdit.Action>)
    }

    @Dependency(\.toast) var toast
    var userDefaults: UserDefaults = .shared

    var body: some ReducerProtocol<State, Action> {
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
                state.editingModel = .init(model: model)
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
        }.ifLet(\.$editingModel, action: /Action.chatModelItem) {
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


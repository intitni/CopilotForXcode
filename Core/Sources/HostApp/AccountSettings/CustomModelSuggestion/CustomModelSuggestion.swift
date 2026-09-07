import ComposableArchitecture
import Foundation

/// Settings of the built-in custom model suggestion provider.
@Reducer
struct CustomModelSuggestion {
    @ObservableState
    struct State: Equatable {
        var completionModel = CompletionModelEdit.State(format: .openAI)
        var fimModel = FIMModelEdit.State(format: .mistral)
        var tabbyModel = TabbyModelEdit.State(
            authorizationMode: .none,
            authorizationHeaderName: "",
            username: ""
        )
    }

    enum Action {
        case completionModel(CompletionModelEdit.Action)
        case fimModel(FIMModelEdit.Action)
        case tabbyModel(TabbyModelEdit.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.completionModel, action: \.completionModel) {
            CompletionModelEdit()
        }
        Scope(state: \.fimModel, action: \.fimModel) {
            FIMModelEdit()
        }
        Scope(state: \.tabbyModel, action: \.tabbyModel) {
            TabbyModelEdit()
        }
    }
}

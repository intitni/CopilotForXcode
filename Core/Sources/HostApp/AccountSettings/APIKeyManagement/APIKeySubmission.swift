import ComposableArchitecture
import Foundation

@Reducer
struct APIKeySubmission {
    @ObservableState
    struct State: Equatable {
        var name: String = ""
        var key: String = ""
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveButtonClicked
        case cancelButtonClicked
        case saveFinished
    }

    @Dependency(\.toast) var toast
    @Dependency(\.apiKeyKeychain) var keychain

    enum E: Error, LocalizedError {
        case nameIsEmpty
        case keyIsEmpty
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .saveButtonClicked:
                do {
                    guard !state.name.isEmpty else { throw E.nameIsEmpty }
                    guard !state.key.isEmpty else { throw E.keyIsEmpty }

                    try keychain.update(
                        state.key,
                        key: state.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    return .run { send in
                        await send(.saveFinished)
                    }
                } catch {
                    toast(error.localizedDescription, .error)
                    return .none
                }

            case .cancelButtonClicked:
                return .none

            case .saveFinished:
                return .none

            case .binding:
                return .none
            }
        }
    }
}


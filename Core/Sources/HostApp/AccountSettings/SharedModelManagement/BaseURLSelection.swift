import ComposableArchitecture
import Foundation
import Preferences
import SwiftUI

struct BaseURLSelection: ReducerProtocol {
    struct State: Equatable {
        @BindingState var baseURL: String = ""
        var availableBaseURLs: [String] = []
    }

    enum Action: Equatable, BindableAction {
        case appear
        case refreshAvailableBaseURLNames
        case binding(BindingAction<State>)
    }

    @Dependency(\.toast) var toast
    @Dependency(\.userDefaults) var userDefaults

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in
                    await send(.refreshAvailableBaseURLNames)
                }

            case .refreshAvailableBaseURLNames:
                let chatModels = userDefaults.value(for: \.chatModels)
                let embeddingModels = userDefaults.value(for: \.embeddingModels)
                var allBaseURLs = Set(
                    chatModels.map(\.info.baseURL) + embeddingModels.map(\.info.baseURL)
                )
                state.availableBaseURLs = Array(allBaseURLs).sorted()
                return .none

            case .binding:
                return .none
            }
        }
    }
}


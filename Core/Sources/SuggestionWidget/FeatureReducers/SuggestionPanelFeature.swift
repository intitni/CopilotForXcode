import ComposableArchitecture
import Foundation
import SwiftUI

struct SuggestionPanelFeature: ReducerProtocol {
    struct State: Equatable {
        var content: SharedPanelFeature.Content?
        var colorScheme: ColorScheme = .light
        var alignTopToAnchor = false
        var isPanelDisplayed: Bool = false
        var isPanelOutOfFrame: Bool = false
        var opacity: Double {
            guard isPanelDisplayed else { return 0 }
            if isPanelOutOfFrame { return 0 }
            guard content != nil else { return 0 }
            return 1
        }
    }

    enum Action: Equatable {
        case noAction
    }

    var body: some ReducerProtocol<State, Action> {
        Reduce { _, _ in .none }
    }
}

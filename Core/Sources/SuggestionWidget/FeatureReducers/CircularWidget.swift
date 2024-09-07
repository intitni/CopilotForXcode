import ActiveApplicationMonitor
import ComposableArchitecture
import Preferences
import SuggestionBasic
import SwiftUI

@Reducer
public struct CircularWidget {
    public struct IsProcessingCounter: Equatable {
        var expirationDate: TimeInterval
    }

    @ObservableState
    public struct State: Equatable {
        var isProcessingCounters = [IsProcessingCounter]()
        var isProcessing: Bool
        var isDisplayingContent: Bool
        var isContentEmpty: Bool
        var isChatPanelDetached: Bool
        var isChatOpen: Bool
    }

    public enum Action: Equatable {
        case widgetClicked
        case detachChatPanelToggleClicked
        case openChatButtonClicked
        case runCustomCommandButtonClicked(CustomCommand)
        case markIsProcessing
        case endIsProcessing
        case _forceEndIsProcessing
    }

    struct CancelAutoEndIsProcessKey: Hashable {}

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .detachChatPanelToggleClicked:
                return .none // handled elsewhere
                
            case .openChatButtonClicked:
                return .run { _ in
                    suggestionWidgetControllerDependency.onOpenChatClicked()
                }
                
            case let .runCustomCommandButtonClicked(command):
                return .run { _ in
                    suggestionWidgetControllerDependency.onCustomCommandClicked(command)
                }
                
            case .widgetClicked:
                return .none // handled elsewhere
                
            case .markIsProcessing:
                let deadline = Date().timeIntervalSince1970 + 20
                state.isProcessingCounters.append(IsProcessingCounter(expirationDate: deadline))
                state.isProcessing = true
                return .run { send in
                    try await Task.sleep(nanoseconds: 20 * 1_000_000_000)
                    try Task.checkCancellation()
                    await send(._forceEndIsProcessing)
                }.cancellable(id: CancelAutoEndIsProcessKey(), cancelInFlight: true)
                
            case .endIsProcessing:
                if !state.isProcessingCounters.isEmpty {
                    state.isProcessingCounters.removeFirst()
                }
                state.isProcessingCounters
                    .removeAll(where: { $0.expirationDate < Date().timeIntervalSince1970 })
                state.isProcessing = !state.isProcessingCounters.isEmpty
                return .none
                
            case ._forceEndIsProcessing:
                state.isProcessingCounters.removeAll()
                state.isProcessing = false
                return .none
            }
        }
    }
}


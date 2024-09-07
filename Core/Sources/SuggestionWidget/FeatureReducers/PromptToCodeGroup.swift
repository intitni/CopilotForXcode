import ComposableArchitecture
import Foundation
import PromptToCodeService
import SuggestionBasic
import XcodeInspector

@Reducer
public struct PromptToCodeGroup {
    @ObservableState
    public struct State {
        public var promptToCodes: IdentifiedArrayOf<PromptToCodePanel.State> = []
        public var activeDocumentURL: PromptToCodePanel.State.ID? = XcodeInspector.shared
            .realtimeActiveDocumentURL
        public var activePromptToCode: PromptToCodePanel.State? {
            get {
                if let detached = promptToCodes
                    .first(where: { !$0.promptToCodeState.isAttachedToTarget })
                {
                    return detached
                }
                guard let id = activeDocumentURL else { return nil }
                return promptToCodes[id: id]
            }
            set {
                if let id = newValue?.id {
                    promptToCodes[id: id] = newValue
                }
            }
        }
    }

    public enum Action {
        /// Activate the prompt to code if it exists or create it if it doesn't
        case activateOrCreatePromptToCode(PromptToCodePanel.State)
        case createPromptToCode(PromptToCodePanel.State)
        case updatePromptToCodeRange(
            id: PromptToCodePanel.State.ID,
            snippetId: UUID,
            range: CursorRange
        )
        case discardAcceptedPromptToCodeIfNotContinuous(id: PromptToCodePanel.State.ID)
        case updateActivePromptToCode(documentURL: URL)
        case discardExpiredPromptToCode(documentURLs: [URL])
        case promptToCode(PromptToCodePanel.State.ID, PromptToCodePanel.Action)
        case activePromptToCode(PromptToCodePanel.Action)
    }

    @Dependency(\.promptToCodeServiceFactory) var promptToCodeServiceFactory
    @Dependency(\.activatePreviousActiveXcode) var activatePreviousActiveXcode

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .activateOrCreatePromptToCode(s):
                if let promptToCode = state.activePromptToCode {
                    return .run { send in
                        await send(.promptToCode(promptToCode.id, .focusOnTextField))
                    }
                }
                return .run { send in
                    await send(.createPromptToCode(s))
                }
            case let .createPromptToCode(newPromptToCode):
                // insert at 0 so it has high priority then the other detached prompt to codes
                state.promptToCodes.insert(newPromptToCode, at: 0)
                return .run { send in
                    if !newPromptToCode.promptToCodeState.instruction.isEmpty {
                        await send(.promptToCode(newPromptToCode.id, .modifyCodeButtonTapped))
                    }
                }.cancellable(
                    id: PromptToCodePanel.CancellationKey.modifyCode(newPromptToCode.id),
                    cancelInFlight: true
                )

            case let .updatePromptToCodeRange(id, snippetId, range):
                if let p = state.promptToCodes[id: id], p.promptToCodeState.isAttachedToTarget {
                    state.promptToCodes[id: id]?.promptToCodeState.snippets[id: snippetId]?
                        .attachedRange = range
                }
                return .none

            case let .discardAcceptedPromptToCodeIfNotContinuous(id):
                state.promptToCodes.removeAll { $0.id == id && $0.hasEnded }
                return .none

            case let .updateActivePromptToCode(documentURL):
                state.activeDocumentURL = documentURL
                return .none

            case let .discardExpiredPromptToCode(documentURLs):
                for url in documentURLs {
                    state.promptToCodes.remove(id: url)
                }
                return .none

            case .promptToCode:
                return .none

            case .activePromptToCode:
                return .none
            }
        }
        .ifLet(\.activePromptToCode, action: \.activePromptToCode) {
            PromptToCodePanel()
                .dependency(\.promptToCodeService, promptToCodeServiceFactory())
        }
        .forEach(\.promptToCodes, action: /Action.promptToCode, element: {
            PromptToCodePanel()
                .dependency(\.promptToCodeService, promptToCodeServiceFactory())
        })

        Reduce { state, action in
            switch action {
            case let .promptToCode(id, .cancelButtonTapped):
                state.promptToCodes.remove(id: id)
                return .run { _ in
                    activatePreviousActiveXcode()
                }
            case .activePromptToCode(.cancelButtonTapped):
                guard let id = state.activePromptToCode?.id else { return .none }
                state.promptToCodes.remove(id: id)
                return .run { _ in
                    activatePreviousActiveXcode()
                }
            default: return .none
            }
        }
    }
}


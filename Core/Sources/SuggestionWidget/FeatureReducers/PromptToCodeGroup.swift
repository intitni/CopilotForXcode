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
        public var selectedTabId: URL?
        public var activePromptToCode: PromptToCodePanel.State? {
            get {
                guard let selectedTabId else { return promptToCodes.first }
                return promptToCodes[id: selectedTabId] ?? promptToCodes.first
            }
            set {
                selectedTabId = newValue?.id
                if let id = selectedTabId {
                    promptToCodes[id: id] = newValue
                }
            }
        }
    }

    public enum Action {
        /// Activate the prompt to code if it exists or create it if it doesn't
        case activateOrCreatePromptToCode(PromptToCodePanel.State)
        case createPromptToCode(PromptToCodePanel.State, sendImmediately: Bool)
        case updatePromptToCodeRange(
            id: PromptToCodePanel.State.ID,
            snippetId: UUID,
            range: CursorRange
        )
        case discardAcceptedPromptToCodeIfNotContinuous(id: PromptToCodePanel.State.ID)
        case updateActivePromptToCode(documentURL: URL)
        case discardExpiredPromptToCode(documentURLs: [URL])
        case tabClicked(id: URL)
        case closeTabButtonClicked(id: URL)
        case switchToNextTab
        case switchToPreviousTab
        case promptToCode(IdentifiedActionOf<PromptToCodePanel>)
        case activePromptToCode(PromptToCodePanel.Action)
    }

    @Dependency(\.activatePreviousActiveXcode) var activatePreviousActiveXcode

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .activateOrCreatePromptToCode(s):
                if let promptToCode = state.activePromptToCode, s.id == promptToCode.id {
                    state.selectedTabId = promptToCode.id
                    return .run { send in
                        await send(.promptToCode(.element(
                            id: promptToCode.id,
                            action: .focusOnTextField
                        )))
                    }
                }
                return .run { send in
                    await send(.createPromptToCode(s, sendImmediately: false))
                }
            case let .createPromptToCode(newPromptToCode, sendImmediately):
                var newPromptToCode = newPromptToCode
                newPromptToCode.isActiveDocument = newPromptToCode.id == state.activeDocumentURL
                state.promptToCodes.append(newPromptToCode)
                state.selectedTabId = newPromptToCode.id
                return .run { [newPromptToCode] send in
                    if sendImmediately,
                       !newPromptToCode.contextInputController.instruction.string.isEmpty
                    {
                        await send(.promptToCode(.element(
                            id: newPromptToCode.id,
                            action: .modifyCodeButtonTapped
                        )))
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
                for itemId in state.promptToCodes.ids {
                    if itemId == id, state.promptToCodes[id: itemId]?.clickedButton == .accept {
                        state.promptToCodes.remove(id: itemId)
                    } else {
                        state.promptToCodes[id: itemId]?.clickedButton = nil
                    }
                }
                return .none

            case let .updateActivePromptToCode(documentURL):
                state.activeDocumentURL = documentURL
                for index in state.promptToCodes.indices {
                    state.promptToCodes[index].isActiveDocument =
                        state.promptToCodes[index].id == documentURL
                }
                return .none

            case let .discardExpiredPromptToCode(documentURLs):
                for url in documentURLs {
                    state.promptToCodes.remove(id: url)
                }
                return .none

            case let .tabClicked(id):
                state.selectedTabId = id
                return .none

            case let .closeTabButtonClicked(id):
                return .run { send in
                    await send(.promptToCode(.element(
                        id: id,
                        action: .cancelButtonTapped
                    )))
                }

            case .switchToNextTab:
                if let selectedTabId = state.selectedTabId,
                   let index = state.promptToCodes.index(id: selectedTabId)
                {
                    let nextIndex = (index + 1) % state.promptToCodes.count
                    state.selectedTabId = state.promptToCodes[nextIndex].id
                }
                return .none

            case .switchToPreviousTab:
                if let selectedTabId = state.selectedTabId,
                   let index = state.promptToCodes.index(id: selectedTabId)
                {
                    let previousIndex = (index - 1 + state.promptToCodes.count) % state
                        .promptToCodes.count
                    state.selectedTabId = state.promptToCodes[previousIndex].id
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
        }
        .forEach(\.promptToCodes, action: \.promptToCode, element: {
            PromptToCodePanel()
        })

        Reduce { state, action in
            switch action {
            case let .promptToCode(.element(id, .cancelButtonTapped)):
                state.promptToCodes.remove(id: id)
                let isEmpty = state.promptToCodes.isEmpty
                return .run { _ in
                    if isEmpty {
                        activatePreviousActiveXcode()
                    }
                }
            case .activePromptToCode(.cancelButtonTapped):
                guard let id = state.selectedTabId else { return .none }
                state.promptToCodes.remove(id: id)
                let isEmpty = state.promptToCodes.isEmpty
                return .run { _ in
                    if isEmpty {
                        activatePreviousActiveXcode()
                    }
                }
            default: return .none
            }
        }
    }
}


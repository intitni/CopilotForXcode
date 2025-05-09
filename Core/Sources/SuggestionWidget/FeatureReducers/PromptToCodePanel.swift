import AppKit
import ComposableArchitecture
import CustomAsyncAlgorithms
import Dependencies
import Foundation
import ModificationBasic
import Preferences
import PromptToCodeCustomization
import PromptToCodeService
import SuggestionBasic
import XcodeInspector

@Reducer
public struct PromptToCodePanel {
    @ObservableState
    public struct State: Identifiable {
        public enum FocusField: Equatable {
            case textField
        }
        
        public enum ClickedButton: Equatable {
            case accept
            case acceptAndContinue
        }

        @Shared public var promptToCodeState: ModificationState
        @ObservationStateIgnored
        public var contextInputController: PromptToCodeContextInputController

        public var id: URL { promptToCodeState.source.documentURL }

        public var commandName: String?
        public var isContinuous: Bool
        public var focusedField: FocusField? = .textField

        public var filename: String {
            promptToCodeState.source.documentURL.lastPathComponent
        }

        public var canRevert: Bool { !promptToCodeState.history.isEmpty }

        public var generateDescriptionRequirement: Bool

        public var clickedButton: ClickedButton?
        
        public var isActiveDocument: Bool = false

        public var snippetPanels: IdentifiedArrayOf<PromptToCodeSnippetPanel.State> {
            get {
                IdentifiedArrayOf(
                    uniqueElements: promptToCodeState.snippets.map {
                        PromptToCodeSnippetPanel.State(snippet: $0)
                    }
                )
            }
            set {
                promptToCodeState.snippets = IdentifiedArrayOf(
                    uniqueElements: newValue.map(\.snippet)
                )
            }
        }

        public init(
            promptToCodeState: Shared<ModificationState>,
            instruction: String?,
            commandName: String? = nil,
            isContinuous: Bool = false,
            generateDescriptionRequirement: Bool = UserDefaults.shared
                .value(for: \.promptToCodeGenerateDescription)
        ) {
            _promptToCodeState = promptToCodeState
            self.isContinuous = isContinuous
            self.generateDescriptionRequirement = generateDescriptionRequirement
            self.commandName = commandName
            contextInputController = PromptToCodeCustomization
                .contextInputControllerFactory(promptToCodeState)
            focusedField = .textField
            contextInputController.instruction = instruction
                .map(NSAttributedString.init(string:)) ?? .init()
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case focusOnTextField
        case selectionRangeToggleTapped
        case modifyCodeButtonTapped
        case revertButtonTapped
        case stopRespondingButtonTapped
        case modifyCodeFinished
        case modifyCodeCancelled
        case cancelButtonTapped
        case acceptButtonTapped
        case acceptAndContinueButtonTapped
        case revealFileButtonClicked
        case statusUpdated([String])
        case snippetPanel(IdentifiedActionOf<PromptToCodeSnippetPanel>)
    }

    @Dependency(\.commandHandler) var commandHandler
    @Dependency(\.activateThisApp) var activateThisApp
    @Dependency(\.activatePreviousActiveXcode) var activatePreviousActiveXcode

    enum CancellationKey: Hashable {
        case modifyCode(State.ID)
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .snippetPanel:
                return .none

            case .focusOnTextField:
                state.focusedField = .textField
                return .none

            case .selectionRangeToggleTapped:
                state.promptToCodeState.isAttachedToTarget.toggle()
                return .none

            case .modifyCodeButtonTapped:
                guard !state.promptToCodeState.isGenerating else { return .none }
                let copiedState = state
                let contextInputController = state.contextInputController
                state.promptToCodeState.isGenerating = true
                state.promptToCodeState
                    .pushHistory(instruction: .init(
                        attributedString: contextInputController
                            .instruction
                    ))
                let snippets = state.promptToCodeState.snippets

                return .run { send in
                    do {
                        let context = await contextInputController.resolveContext(onStatusChange: {
                            await send(.statusUpdated($0))
                        })
                        let agentFactory = context.agent ?? { SimpleModificationAgent() }
                        _ = try await withThrowingTaskGroup(of: Void.self) { group in
                            for (index, snippet) in snippets.enumerated() {
                                if index > 3 { // at most 3 at a time
                                    _ = try await group.next()
                                }
                                group.addTask {
                                    try await Task
                                        .sleep(nanoseconds: UInt64.random(in: 0...1_000_000_000))
                                    let agent = agentFactory()
                                    let stream = agent.send(.init(
                                        code: snippet.originalCode,
                                        requirement: context.instruction,
                                        source: .init(
                                            language: copiedState.promptToCodeState.source.language,
                                            documentURL: copiedState.promptToCodeState.source
                                                .documentURL,
                                            projectRootURL: copiedState.promptToCodeState.source
                                                .projectRootURL,
                                            content: copiedState.promptToCodeState.source.content,
                                            lines: copiedState.promptToCodeState.source.lines
                                        ),
                                        isDetached: !copiedState.promptToCodeState
                                            .isAttachedToTarget,
                                        extraSystemPrompt: copiedState.promptToCodeState
                                            .extraSystemPrompt,
                                        range: snippet.attachedRange,
                                        references: context.references,
                                        topics: context.topics
                                    )).timedDebounce(for: 0.4)

                                    do {
                                        for try await response in stream {
                                            try Task.checkCancellation()

                                            switch response {
                                            case let .code(code):
                                                await send(.snippetPanel(.element(
                                                    id: snippet.id,
                                                    action: .modifyCodeChunkReceived(
                                                        code: code,
                                                        description: ""
                                                    )
                                                )))
                                            }
                                        }
                                    } catch is CancellationError {
                                        throw CancellationError()
                                    } catch {
                                        try Task.checkCancellation()
                                        if (error as NSError).code == NSURLErrorCancelled {
                                            await send(.snippetPanel(.element(
                                                id: snippet.id,
                                                action: .modifyCodeFailed(error: "Cancelled")
                                            )))
                                            return
                                        }
                                        await send(.snippetPanel(.element(
                                            id: snippet.id,
                                            action: .modifyCodeFailed(
                                                error: error.localizedDescription
                                            )
                                        )))
                                    }
                                }
                            }

                            try await group.waitForAll()
                        }

                        await send(.modifyCodeFinished)
                    } catch is CancellationError {
                        try Task.checkCancellation()
                        await send(.modifyCodeCancelled)
                    } catch {
                        await send(.modifyCodeFinished)
                    }
                }.cancellable(id: CancellationKey.modifyCode(state.id), cancelInFlight: true)

            case .revertButtonTapped:
                if let instruction = state.promptToCodeState.popHistory() {
                    state.contextInputController.instruction = instruction
                }
                return .none

            case .stopRespondingButtonTapped:
                state.promptToCodeState.isGenerating = false
                state.promptToCodeState.status = []
                return .cancel(id: CancellationKey.modifyCode(state.id))

            case .modifyCodeFinished:
                state.contextInputController.instruction = .init("")
                state.promptToCodeState.isGenerating = false
                state.promptToCodeState.status = []

                if state.promptToCodeState.snippets.allSatisfy({ snippet in
                    snippet.modifiedCode.isEmpty && snippet.description.isEmpty && snippet
                        .error == nil
                }) {
                    // if both code and description are empty, we treat it as failed
                    return .run { send in
                        await send(.revertButtonTapped)
                    }
                }
                return .none

            case .modifyCodeCancelled:
                state.promptToCodeState.isGenerating = false
                return .none

            case .cancelButtonTapped:
                return .cancel(id: CancellationKey.modifyCode(state.id))

            case .acceptButtonTapped:
                state.clickedButton = .accept
                return .run { _ in
                    await commandHandler.acceptModification()
                    activatePreviousActiveXcode()
                }

            case .acceptAndContinueButtonTapped:
                state.clickedButton = .acceptAndContinue
                return .run { _ in
                    await commandHandler.acceptModification()
                    activateThisApp()
                }

            case .revealFileButtonClicked:
                let url = state.promptToCodeState.source.documentURL
                let startLine = state.snippetPanels.first?.snippet.attachedRange.start.line ?? 0
                return .run { _ in
                    await commandHandler.presentFile(at: url, line: startLine)
                }

            case let .statusUpdated(status):
                state.promptToCodeState.status = status
                return .none
            }
        }

        Reduce { _, _ in .none }.forEach(\.snippetPanels, action: \.snippetPanel) {
            PromptToCodeSnippetPanel()
        }
    }
}

@Reducer
public struct PromptToCodeSnippetPanel {
    @ObservableState
    public struct State: Identifiable {
        public var id: UUID { snippet.id }
        var snippet: ModificationSnippet
    }

    public enum Action {
        case modifyCodeFinished
        case modifyCodeChunkReceived(code: String, description: String)
        case modifyCodeFailed(error: String)
        case copyCodeButtonTapped
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .modifyCodeFinished:
                return .none

            case let .modifyCodeChunkReceived(code, description):
                state.snippet.modifiedCode = code
                state.snippet.description = description
                return .none

            case let .modifyCodeFailed(error):
                state.snippet.error = error
                return .none

            case .copyCodeButtonTapped:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.snippet.modifiedCode, forType: .string)
                return .none
            }
        }
    }
}

final class DefaultPromptToCodeContextInputControllerDelegate: PromptToCodeContextInputControllerDelegate {
    let store: StoreOf<PromptToCodePanel>

    init(store: StoreOf<PromptToCodePanel>) {
        self.store = store
    }

    func modifyCodeButtonClicked() {
        Task {
            await store.send(.modifyCodeButtonTapped)
        }
    }
}


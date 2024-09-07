import AppKit
import ComposableArchitecture
import CustomAsyncAlgorithms
import Dependencies
import Foundation
import Preferences
import PromptToCodeBasic
import PromptToCodeCustomization
import PromptToCodeService
import SuggestionBasic

@Reducer
public struct PromptToCodePanel {
    @ObservableState
    public struct State: Identifiable {
        public enum FocusField: Equatable {
            case textField
        }

        @Shared public var promptToCodeState: PromptToCodeState

        public var id: URL { promptToCodeState.source.documentURL }

        public var indentSize: Int
        public var usesTabsForIndentation: Bool
        public var commandName: String?
        public var isContinuous: Bool
        public var focusedField: FocusField? = .textField

        public var filename: String {
            promptToCodeState.source.documentURL.lastPathComponent
        }

        public var canRevert: Bool { !promptToCodeState.history.isEmpty }

        public var generateDescriptionRequirement: Bool
        
        public var hasEnded = false

        public var snippetPanels: IdentifiedArrayOf<PromptToCodeSnippetPanel.State> {
            get {
                IdentifiedArrayOf(
                    uniqueElements: promptToCodeState.snippets.reversed().map {
                        PromptToCodeSnippetPanel.State(snippet: $0)
                    }
                )
            }
            set {
                promptToCodeState.snippets = IdentifiedArrayOf(
                    uniqueElements: newValue.map(\.snippet).reversed()
                )
            }
        }

        public init(
            promptToCodeState: Shared<PromptToCodeState>,
            indentSize: Int,
            usesTabsForIndentation: Bool,
            commandName: String? = nil,
            isContinuous: Bool = false,
            generateDescriptionRequirement: Bool = UserDefaults.shared
                .value(for: \.promptToCodeGenerateDescription)
        ) {
            _promptToCodeState = promptToCodeState
            self.isContinuous = isContinuous
            self.indentSize = indentSize
            self.usesTabsForIndentation = usesTabsForIndentation
            self.generateDescriptionRequirement = generateDescriptionRequirement
            self.commandName = commandName
            focusedField = .textField
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
        case appendNewLineToPromptButtonTapped
        case snippetPanel(IdentifiedActionOf<PromptToCodeSnippetPanel>)
    }

    @Dependency(\.commandHandler) var commandHandler
    @Dependency(\.promptToCodeService) var promptToCodeService
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
                state.promptToCodeState.isGenerating = true
                state.promptToCodeState.pushHistory()
                let snippets = state.promptToCodeState.snippets

                return .run { send in
                    do {
                        _ = try await withThrowingTaskGroup(of: Void.self) { group in
                            for snippet in snippets {
                                group.addTask {
                                    let stream = try await promptToCodeService.modifyCode(
                                        code: snippet.originalCode,
                                        requirement: copiedState.promptToCodeState.instruction,
                                        source: .init(
                                            language: copiedState.promptToCodeState.source.language,
                                            documentURL: copiedState.promptToCodeState.source
                                                .documentURL,
                                            projectRootURL: copiedState.promptToCodeState.source
                                                .projectRootURL,
                                            content: copiedState.promptToCodeState.source.content,
                                            lines: copiedState.promptToCodeState.source.lines,
                                            range: snippet.attachedRange
                                        ),
                                        isDetached: !copiedState.promptToCodeState
                                            .isAttachedToTarget,
                                        extraSystemPrompt: copiedState.promptToCodeState
                                            .extraSystemPrompt,
                                        generateDescriptionRequirement: copiedState
                                            .generateDescriptionRequirement
                                    ).timedDebounce(for: 0.2)

                                    do {
                                        for try await fragment in stream {
                                            try Task.checkCancellation()
                                            await send(.snippetPanel(.element(
                                                id: snippet.id,
                                                action: .modifyCodeChunkReceived(
                                                    code: fragment.code,
                                                    description: fragment.description
                                                )
                                            )))
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
                                                error: error
                                                    .localizedDescription
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
                state.promptToCodeState.popHistory()
                return .none

            case .stopRespondingButtonTapped:
                state.promptToCodeState.isGenerating = false
                promptToCodeService.stopResponding()
                return .cancel(id: CancellationKey.modifyCode(state.id))

            case .modifyCodeFinished:
                state.promptToCodeState.instruction = ""
                state.promptToCodeState.isGenerating = false

                if state.promptToCodeState.snippets.allSatisfy({ snippet in
                    snippet.modifiedCode.isEmpty && snippet.description.isEmpty
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
                promptToCodeService.stopResponding()
                return .cancel(id: CancellationKey.modifyCode(state.id))

            case .acceptButtonTapped:
                state.hasEnded = true
                return .run { _ in
                    await commandHandler.acceptPromptToCode()
                    activatePreviousActiveXcode()
                }
                
            case .acceptAndContinueButtonTapped:
                return .run { _ in
                    await commandHandler.acceptPromptToCode()
                    activateThisApp()
                }

            case .appendNewLineToPromptButtonTapped:
                state.promptToCodeState.instruction += "\n"
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
        var snippet: PromptToCodeSnippet
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


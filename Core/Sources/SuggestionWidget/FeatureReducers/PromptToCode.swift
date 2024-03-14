import AppKit
import ComposableArchitecture
import Dependencies
import Foundation
import PromptToCodeService
import SuggestionModel

public struct PromptToCodeAcceptHandlerDependencyKey: DependencyKey {
    public static let liveValue: (PromptToCode.State) -> Void = { _ in
        assertionFailure("Please provide a handler")
    }

    public static let previewValue: (PromptToCode.State) -> Void = { _ in
        print("Accept Prompt to Code")
    }
}

public extension DependencyValues {
    var promptToCodeAcceptHandler: (PromptToCode.State) -> Void {
        get { self[PromptToCodeAcceptHandlerDependencyKey.self] }
        set { self[PromptToCodeAcceptHandlerDependencyKey.self] = newValue }
    }
}

public struct PromptToCode: ReducerProtocol {
    public struct State: Equatable, Identifiable {
        public indirect enum HistoryNode: Equatable {
            case empty
            case node(code: String, description: String, previous: HistoryNode)

            mutating func enqueue(code: String, description: String) {
                let current = self
                self = .node(code: code, description: description, previous: current)
            }

            mutating func pop() -> (code: String, description: String)? {
                switch self {
                case .empty:
                    return nil
                case let .node(code, description, previous):
                    self = previous
                    return (code, description)
                }
            }
        }
        
        public enum FocusField: Equatable {
            case textField
        }

        public var id: URL { documentURL }
        public var history: HistoryNode
        public var code: String
        public var isResponding: Bool
        public var description: String
        public var error: String?
        public var selectionRange: CursorRange?
        public var language: CodeLanguage
        public var indentSize: Int
        public var usesTabsForIndentation: Bool
        public var projectRootURL: URL
        public var documentURL: URL
        public var allCode: String
        public var allLines: [String]
        public var extraSystemPrompt: String?
        public var generateDescriptionRequirement: Bool?
        public var commandName: String?
        @BindingState public var prompt: String
        @BindingState public var isContinuous: Bool
        @BindingState public var isAttachedToSelectionRange: Bool
        @BindingState public var focusedField: FocusField? = .textField

        public var filename: String { documentURL.lastPathComponent }
        public var canRevert: Bool { history != .empty }

        public init(
            code: String,
            prompt: String,
            language: CodeLanguage,
            indentSize: Int,
            usesTabsForIndentation: Bool,
            projectRootURL: URL,
            documentURL: URL,
            allCode: String,
            allLines: [String],
            commandName: String? = nil,
            description: String = "",
            isResponding: Bool = false,
            isAttachedToSelectionRange: Bool = true,
            error: String? = nil,
            history: HistoryNode = .empty,
            isContinuous: Bool = false,
            selectionRange: CursorRange? = nil,
            extraSystemPrompt: String? = nil,
            generateDescriptionRequirement: Bool? = nil
        ) {
            self.history = history
            self.code = code
            self.prompt = prompt
            self.isResponding = isResponding
            self.description = description
            self.error = error
            self.isContinuous = isContinuous
            self.selectionRange = selectionRange
            self.language = language
            self.indentSize = indentSize
            self.usesTabsForIndentation = usesTabsForIndentation
            self.projectRootURL = projectRootURL
            self.documentURL = documentURL
            self.allCode = allCode
            self.allLines = allLines
            self.extraSystemPrompt = extraSystemPrompt
            self.generateDescriptionRequirement = generateDescriptionRequirement
            self.isAttachedToSelectionRange = isAttachedToSelectionRange
            self.commandName = commandName
            
            if selectionRange?.isEmpty ?? true {
                self.isAttachedToSelectionRange = false
            }
        }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case focusOnTextField
        case selectionRangeToggleTapped
        case modifyCodeButtonTapped
        case revertButtonTapped
        case stopRespondingButtonTapped
        case modifyCodeFinished
        case modifyCodeChunkReceived(code: String, description: String)
        case modifyCodeFailed(error: String)
        case modifyCodeCancelled
        case cancelButtonTapped
        case acceptButtonTapped
        case copyCodeButtonTapped
        case appendNewLineToPromptButtonTapped
    }

    @Dependency(\.promptToCodeService) var promptToCodeService
    @Dependency(\.promptToCodeAcceptHandler) var promptToCodeAcceptHandler

    enum CancellationKey: Hashable {
        case modifyCode(State.ID)
    }

    public var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .focusOnTextField:
                state.focusedField = .textField
                return .none

            case .selectionRangeToggleTapped:
                state.isAttachedToSelectionRange.toggle()
                return .none

            case .modifyCodeButtonTapped:
                guard !state.isResponding else { return .none }
                let copiedState = state
                state.history.enqueue(code: state.code, description: state.description)
                state.isResponding = true
                state.code = ""
                state.description = ""
                state.error = nil

                return .run { send in
                    do {
                        let stream = try await promptToCodeService.modifyCode(
                            code: copiedState.code,
                            requirement: copiedState.prompt,
                            source: .init(
                                language: copiedState.language,
                                documentURL: copiedState.documentURL,
                                projectRootURL: copiedState.projectRootURL,
                                content: copiedState.allCode,
                                lines: copiedState.allLines,
                                range: copiedState.selectionRange ?? .outOfScope
                            ),
                            isDetached: !copiedState.isAttachedToSelectionRange,
                            extraSystemPrompt: copiedState.extraSystemPrompt,
                            generateDescriptionRequirement: copiedState
                                .generateDescriptionRequirement
                        )
                        #warning("TODO: make the action call debounced.")
                        for try await fragment in stream {
                            try Task.checkCancellation()
                            await send(.modifyCodeChunkReceived(
                                code: fragment.code,
                                description: fragment.description
                            ))
                        }
                        try Task.checkCancellation()
                        await send(.modifyCodeFinished)
                    } catch is CancellationError {
                        try Task.checkCancellation()
                        await send(.modifyCodeCancelled)
                    } catch {
                        try Task.checkCancellation()
                        if (error as NSError).code == NSURLErrorCancelled {
                            await send(.modifyCodeCancelled)
                            return
                        }

                        await send(.modifyCodeFailed(error: error.localizedDescription))
                    }
                }.cancellable(id: CancellationKey.modifyCode(state.id), cancelInFlight: true)

            case .revertButtonTapped:
                guard let (code, description) = state.history.pop() else { return .none }
                state.code = code
                state.description = description
                return .none

            case .stopRespondingButtonTapped:
                state.isResponding = false
                promptToCodeService.stopResponding()
                return .cancel(id: CancellationKey.modifyCode(state.id))

            case let .modifyCodeChunkReceived(code, description):
                state.code = code
                state.description = description
                return .none

            case .modifyCodeFinished:
                state.prompt = ""
                state.isResponding = false
                if state.code.isEmpty, state.description.isEmpty {
                    // if both code and description are empty, we treat it as failed
                    return .run { send in
                        await send(.revertButtonTapped)
                    }
                }

                return .none

            case let .modifyCodeFailed(error):
                state.error = error
                state.isResponding = false
                return .run { send in
                    await send(.revertButtonTapped)
                }

            case .modifyCodeCancelled:
                state.isResponding = false
                return .none

            case .cancelButtonTapped:
                promptToCodeService.stopResponding()
                return .none

            case .acceptButtonTapped:
                promptToCodeAcceptHandler(state)
                return .none

            case .copyCodeButtonTapped:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.code, forType: .string)
                return .none

            case .appendNewLineToPromptButtonTapped:
                state.prompt += "\n"
                return .none
            }
        }
    }
}


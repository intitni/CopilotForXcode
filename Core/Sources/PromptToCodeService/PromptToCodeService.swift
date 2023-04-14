import CopilotModel
import CopilotService
import Foundation
import OpenAIService

public final class PromptToCodeService: ObservableObject {
    var designatedPromptToCodeAPI: PromptToCodeAPI?
    var promptToCodeAPI: PromptToCodeAPI {
        designatedPromptToCodeAPI ?? OpenAIPromptToCodeAPI()
    }

    var runningAPI: PromptToCodeAPI?

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

    @Published public var history: HistoryNode
    @Published public var code: String
    @Published public var isResponding: Bool = false
    @Published public var description: String = ""
    @Published public var isContinuous = false
    public var canRevert: Bool { history != .empty }
    public var selectionRange: CursorRange
    public var language: CopilotLanguage
    public var indentSize: Int
    public var usesTabsForIndentation: Bool
    public var projectRootURL: URL
    public var fileURL: URL
    public var allCode: String

    public init(
        code: String,
        selectionRange: CursorRange,
        language: CopilotLanguage,
        identSize: Int,
        usesTabsForIndentation: Bool,
        projectRootURL: URL,
        fileURL: URL,
        allCode: String
    ) {
        self.code = code
        self.selectionRange = selectionRange
        self.language = language
        indentSize = identSize
        self.usesTabsForIndentation = usesTabsForIndentation
        self.projectRootURL = projectRootURL
        self.fileURL = fileURL
        self.allCode = allCode
        self.history = .empty
    }

    public func modifyCode(prompt: String) async throws {
        let api = promptToCodeAPI
        runningAPI = api
        isResponding = true
        let toBeModified = code
        history.enqueue(code: code, description: description)
        code = ""
        description = ""
        defer { isResponding = false }
        do {
            let stream = try await api.modifyCode(
                code: toBeModified,
                language: language,
                indentSize: indentSize,
                usesTabsForIndentation: usesTabsForIndentation,
                requirement: prompt,
                projectRootURL: projectRootURL,
                fileURL: fileURL,
                allCode: allCode
            )
            for try await fragment in stream {
                code = fragment.code
                description = fragment.description
            }
            if code.isEmpty, description.isEmpty {
                revert()
            }
        } catch is CancellationError {
            return
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                return
            }

            revert()
            throw error
        }
    }

    public func revert() {
        guard let (code, description) = history.pop() else { return }
        self.code = code
        self.description = description
    }

    public func generateCompletion() -> CopilotCompletion {
        .init(
            text: code,
            position: selectionRange.start,
            uuid: UUID().uuidString,
            range: selectionRange,
            displayText: code
        )
    }

    public func stopResponding() {
        runningAPI?.stopResponding()
        isResponding = false
    }
}

protocol PromptToCodeAPI {
    func modifyCode(
        code: String,
        language: CopilotLanguage,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        requirement: String,
        projectRootURL: URL,
        fileURL: URL,
        allCode: String
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error>

    func stopResponding()
}

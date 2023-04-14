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

    @Published public var oldCode: String?
    @Published public var code: String
    @Published public var isResponding: Bool = false
    @Published public var description: String = ""
    @Published public var isContinuous = false
    public var oldDescription: String?
    public var canRevert: Bool { oldCode != nil }
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
        usesTabsForIndentation: Bool
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
    }

    public func modifyCode(prompt: String) async throws {
        let api = promptToCodeAPI
        runningAPI = api
        isResponding = true
        let toBeModified = code
        oldDescription = description
        oldCode = code
        code = ""
        description = ""
        defer { isResponding = false }
        do {
            let stream = try await api.modifyCode(
                code: toBeModified,
                language: language,
                indentSize: indentSize,
                usesTabsForIndentation: usesTabsForIndentation,
                requirement: prompt
            )
            for try await fragment in stream {
                Task { @MainActor in
                    code = fragment.code
                    description = fragment.description
                }
            }
        } catch is CancellationError {
            return
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                return
            }

            if let oldCode {
                code = oldCode
            }
            if let oldDescription {
                description = oldDescription
            }
            oldCode = nil
            oldDescription = nil
            throw error
        }
    }

    public func revert() {
        guard let oldCode = oldCode else { return }
        code = oldCode
        if let oldDescription {
            description = oldDescription
        }
        self.oldCode = nil
        oldDescription = nil
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

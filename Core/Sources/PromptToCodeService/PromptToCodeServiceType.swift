import Dependencies
import Foundation
import SuggestionModel

public protocol PromptToCodeServiceType {
    func modifyCode(
        code: String,
        requirement: String,
        source: PromptToCodeSource,
        isDetached: Bool,
        extraSystemPrompt: String?,
        generateDescriptionRequirement: Bool?
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error>

    func stopResponding()
}

public struct PromptToCodeSource {
    public var language: CodeLanguage
    public var documentURL: URL
    public var projectRootURL: URL
    public var allCode: String
    public var range: CursorRange

    public init(
        language: CodeLanguage,
        documentURL: URL,
        projectRootURL: URL,
        allCode: String,
        range: CursorRange
    ) {
        self.language = language
        self.documentURL = documentURL
        self.projectRootURL = projectRootURL
        self.allCode = allCode
        self.range = range
    }
}

public struct PromptToCodeServiceDependencyKey: DependencyKey {
    public static let liveValue: PromptToCodeServiceType = PreviewPromptToCodeService()
    public static let previewValue: PromptToCodeServiceType = PreviewPromptToCodeService()
}

public struct PromptToCodeServiceFactoryDependencyKey: DependencyKey {
    public static let liveValue: () -> PromptToCodeServiceType = { OpenAIPromptToCodeService() }
    public static let previewValue: () -> PromptToCodeServiceType = { PreviewPromptToCodeService() }
}

public extension DependencyValues {
    var promptToCodeService: PromptToCodeServiceType {
        get { self[PromptToCodeServiceDependencyKey.self] }
        set { self[PromptToCodeServiceDependencyKey.self] = newValue }
    }

    var promptToCodeServiceFactory: () -> PromptToCodeServiceType {
        get { self[PromptToCodeServiceFactoryDependencyKey.self] }
        set { self[PromptToCodeServiceFactoryDependencyKey.self] = newValue }
    }
}


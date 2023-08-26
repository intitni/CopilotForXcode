import Dependencies
import Foundation
import SuggestionModel

public protocol PromptToCodeServiceType {
    func modifyCode(
        code: String,
        language: CodeLanguage,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        requirement: String,
        projectRootURL: URL,
        fileURL: URL,
        allCode: String,
        extraSystemPrompt: String?,
        generateDescriptionRequirement: Bool?
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error>

    func stopResponding()
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


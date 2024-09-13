import Dependencies
import Foundation
import SuggestionBasic

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
    public var content: String
    public var lines: [String]
    public var range: CursorRange

    public init(
        language: CodeLanguage,
        documentURL: URL,
        projectRootURL: URL,
        content: String,
        lines: [String],
        range: CursorRange
    ) {
        self.language = language
        self.documentURL = documentURL
        self.projectRootURL = projectRootURL
        self.content = content
        self.lines = lines
        self.range = range
    }
}

public struct PromptToCodeServiceDependencyKey: DependencyKey {
    public static let liveValue: PromptToCodeServiceType = PreviewPromptToCodeService()
    public static let previewValue: PromptToCodeServiceType = PreviewPromptToCodeService()
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

#if canImport(ContextAwarePromptToCodeService)

import ContextAwarePromptToCodeService

extension ContextAwarePromptToCodeService: PromptToCodeServiceType {
    public func stopResponding() {}

    public func modifyCode(
        code: String,
        requirement: String,
        source: PromptToCodeSource,
        isDetached: Bool,
        extraSystemPrompt: String?,
        generateDescriptionRequirement: Bool?
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error> {
        try await modifyCode(
            code: code,
            requirement: requirement,
            source: ContextAwarePromptToCodeService.Source(
                language: source.language,
                documentURL: source.documentURL,
                projectRootURL: source.projectRootURL,
                content: source.content,
                lines: source.lines,
                range: source.range
            ),
            isDetached: isDetached,
            extraSystemPrompt: extraSystemPrompt,
            generateDescriptionRequirement: generateDescriptionRequirement
        )
    }
}

public struct PromptToCodeServiceFactoryDependencyKey: DependencyKey {
    public static let liveValue: () -> PromptToCodeServiceType = {
        ContextAwarePromptToCodeService()
    }

    public static let previewValue: () -> PromptToCodeServiceType = {
        PreviewPromptToCodeService()
    }
}

#else

public struct PromptToCodeServiceFactoryDependencyKey: DependencyKey {
    public static let liveValue: () -> PromptToCodeServiceType = {
        OpenAIPromptToCodeService()
    }

    public static let previewValue: () -> PromptToCodeServiceType = {
        PreviewPromptToCodeService()
    }
}

#endif


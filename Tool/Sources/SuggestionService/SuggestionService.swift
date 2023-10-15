import AppKit
import Foundation
import Preferences
import SuggestionModel
import UserDefaultsObserver

public struct SuggestionRequest {
    public var fileURL: URL
    public var content: String
    public var cursorPosition: CursorPosition
    public var tabSize: Int
    public var indentSize: Int
    public var usesTabsForIndentation: Bool
    public var ignoreSpaceOnlySuggestions: Bool

    public init(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool
    ) {
        self.fileURL = fileURL
        self.content = content
        self.cursorPosition = cursorPosition
        self.tabSize = tabSize
        self.indentSize = indentSize
        self.usesTabsForIndentation = usesTabsForIndentation
        self.ignoreSpaceOnlySuggestions = ignoreSpaceOnlySuggestions
    }
}

public protocol SuggestionServiceType {
    func getSuggestions(_ request: SuggestionRequest) async throws -> [CodeSuggestion]

    func notifyAccepted(_ suggestion: CodeSuggestion) async
    func notifyRejected(_ suggestions: [CodeSuggestion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
    func cancelRequest() async
    func terminate() async
}

public extension SuggestionServiceType {
    func getSuggestions(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        ignoreSpaceOnlySuggestions: Bool
    ) async throws -> [CodeSuggestion] {
        return try await getSuggestions(.init(
            fileURL: fileURL,
            content: content,
            cursorPosition: cursorPosition,
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation,
            ignoreSpaceOnlySuggestions: ignoreSpaceOnlySuggestions
        ))
    }
}

protocol SuggestionServiceProvider: SuggestionServiceType {}

public actor SuggestionService: SuggestionServiceType {
    static var builtInMiddlewares: [SuggestionServiceMiddleware] = [
        DisabledLanguageSuggestionServiceMiddleware(),
    ]

    static var customMiddlewares: [SuggestionServiceMiddleware] = []

    static var middlewares: [SuggestionServiceMiddleware] {
        builtInMiddlewares + customMiddlewares
    }

    public static func addMiddleware(_ middleware: SuggestionServiceMiddleware) {
        customMiddlewares.append(middleware)
    }

    let projectRootURL: URL
    let onServiceLaunched: (SuggestionServiceType) -> Void
    let providerChangeObserver = UserDefaultsObserver(
        object: UserDefaults.shared,
        forKeyPaths: [UserDefaultPreferenceKeys().suggestionFeatureProvider.key],
        context: nil
    )

    lazy var suggestionProvider: SuggestionServiceProvider = buildService()

    var serviceType: SuggestionFeatureProvider {
        UserDefaults.shared.value(for: \.suggestionFeatureProvider)
    }

    public init(projectRootURL: URL, onServiceLaunched: @escaping (SuggestionServiceType) -> Void) {
        self.projectRootURL = projectRootURL
        self.onServiceLaunched = onServiceLaunched

        providerChangeObserver.onChange = { [weak self] in
            Task { [weak self] in
                guard let self else { return }
                await rebuildService()
            }
        }
    }

    func buildService() -> SuggestionServiceProvider {
        switch serviceType {
        case .codeium:
            return CodeiumSuggestionProvider(
                projectRootURL: projectRootURL,
                onServiceLaunched: onServiceLaunched
            )
        case .gitHubCopilot:
            return GitHubCopilotSuggestionProvider(
                projectRootURL: projectRootURL,
                onServiceLaunched: onServiceLaunched
            )
        }
    }

    func rebuildService() {
        suggestionProvider = buildService()
    }
}

public extension SuggestionService {
    func getSuggestions(
        _ request: SuggestionRequest
    ) async throws -> [SuggestionModel.CodeSuggestion] {
        var getSuggestion = suggestionProvider.getSuggestions

        for middleware in Self.middlewares.reversed() {
            getSuggestion = { request in
                try await middleware.getSuggestion(request, next: getSuggestion)
            }
        }

        return try await getSuggestion(request)
    }

    func notifyAccepted(_ suggestion: SuggestionModel.CodeSuggestion) async {
        await suggestionProvider.notifyAccepted(suggestion)
    }

    func notifyRejected(_ suggestions: [SuggestionModel.CodeSuggestion]) async {
        await suggestionProvider.notifyRejected(suggestions)
    }

    func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        try await suggestionProvider.notifyOpenTextDocument(fileURL: fileURL, content: content)
    }

    func notifyChangeTextDocument(fileURL: URL, content: String) async throws {
        try await suggestionProvider.notifyChangeTextDocument(fileURL: fileURL, content: content)
    }

    func notifyCloseTextDocument(fileURL: URL) async throws {
        try await suggestionProvider.notifyCloseTextDocument(fileURL: fileURL)
    }

    func notifySaveTextDocument(fileURL: URL) async throws {
        try await suggestionProvider.notifySaveTextDocument(fileURL: fileURL)
    }

    #warning("Move the cancellation to this type so that we can also cancel middlewares")
    func cancelRequest() async {
        await suggestionProvider.cancelRequest()
    }

    func terminate() async {
        await suggestionProvider.terminate()
    }
}


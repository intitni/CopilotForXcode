import CopilotForXcodeKit
import Foundation
import Preferences
import Logger
import AIModel

public final class CodeCompletionLogger {
    struct Model {
        var type: String
        var format: String
        var modelName: String
        var baseURL: String
    }

    @TaskLocal public static var logger: CodeCompletionLogger = .init(request: SuggestionRequest(
        fileURL: .init(filePath: "/"),
        relativePath: "",
        language: .plaintext,
        content: "", 
        originalContent: "",
        cursorPosition: .zero,
        tabSize: 0,
        indentSize: 0,
        usesTabsForIndentation: false,
        relevantCodeSnippets: []
    ))

    let request: SuggestionRequest
    var model = Model(type: "", format: "", modelName: "", baseURL: "")
    var prompt: [(message: String, role: String)] = []
    var responses: [String] = []
    var endpoint: String?
    var firstTokenTime: Date?
    var partialCount = 0
    var outputTokens: Int?
    var reasoningTokens: Int?
    let startTime = Date()
    let id = UUID()

    var shouldLogToConsole: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.shared.value(for: \.customSuggestionVerboseLog)
        #endif
    }

    public init(request: SuggestionRequest) {
        self.request = request
    }

    /// The URL the request actually goes to, once the chat API choice is resolved.
    public func logEndpoint(_ url: String) {
        endpoint = url
    }

    public func logModel(_ chatModel: ChatModel) {
        model = .init(
            type: "Chat Completion",
            format: chatModel.format.rawValue,
            modelName: chatModel.info.modelName,
            baseURL: chatModel.info.baseURL
        )
    }

    public func logModel(_ completionModel: CompletionModel) {
        model = .init(
            type: "Completion",
            format: completionModel.format.rawValue,
            modelName: completionModel.info.modelName,
            baseURL: completionModel.info.baseURL
        )
    }

    public func logModel(_ tabbyModel: TabbyModel) {
        model = .init(
            type: "Tabby",
            format: "N/A",
            modelName: "N/A",
            baseURL: tabbyModel.url
        )
    }
    
    public func logModel(_ fimModel: FIMModel) {
        model = .init(
            type: "FIM",
            format: fimModel.format.rawValue,
            modelName: fimModel.info.modelName,
            baseURL: fimModel.info.baseURL
        )
    }

    public func logPrompt(_ prompt: [(message: String, role: String)]) {
        self.prompt = prompt
    }

    public func logResponse(_ response: String) {
        responses.append(response)
    }

    /// Called when the first non-empty token arrives; later calls are ignored.
    public func logFirstToken() {
        if firstTokenTime == nil { firstTokenTime = Date() }
    }

    /// Called every time a partial suggestion is handed to the UI while streaming.
    public func logPartial() {
        partialCount += 1
    }

    /// Token usage reported by the API, when the protocol carries it.
    public func logUsage(outputTokens: Int?, reasoningTokens: Int?) {
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
    }

    public func error(_ error: Error) {
        if error is CancellationError { return }
        if let urlError = error as? URLError, urlError.code == .cancelled { return }
        guard shouldLogToConsole else { return }

        let now = Date()
        let duration = now.timeIntervalSince(startTime)
        let formattedDuration = String(format: "%.2f", duration)

        Logger.service.info("""
        [Request] \(id)

        Duration: \(formattedDuration)
        Error: \(error.localizedDescription).
        """)
    }

    public func finish() {
        guard shouldLogToConsole else { return }

        let now = Date()
        let duration = now.timeIntervalSince(startTime)
        let formattedDuration = String(format: "%.2f", duration)
        let formattedFirstToken = firstTokenTime
            .map { String(format: "%.2f", $0.timeIntervalSince(startTime)) } ?? "n/a"

        Logger.service.info("""
        [Request] \(id)

        Format: \(model.format)
        Model Name: \(model.modelName)
        Base URL: \(model.baseURL)
        Endpoint: \(endpoint ?? "n/a")
        Duration: \(formattedDuration)
        First Token: \(formattedFirstToken)
        Partials: \(partialCount)
        Output Tokens: \(outputTokens.map(String.init) ?? "n/a") (reasoning: \(reasoningTokens.map(String.init) ?? "n/a"))
        ---
        File URL: \(request.fileURL)
        Code Snippets: \(request.relevantCodeSnippets.count) snippets
        CursorPosition: \(request.cursorPosition)
        """)

        Logger.service.info("""
        [Prompt] \(id)

        \(prompt.map { "\($0.role): \($0.message)" }.joined(separator: "\n\n"))
        """)

        Logger.service.info("""
        [Response] \(id)

        \(responses.enumerated().map { "\($0 + 1): \($1)" }.joined(separator: "\n\n"))
        """)
    }
}


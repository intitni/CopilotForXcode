import ChatBasic
import Foundation
import OpenAIService
import Preferences
import WebSearchService

struct SearchFunction: ChatGPTFunction {
    static let dateFormatter = {
        let it = DateFormatter()
        it.dateFormat = "yyyy-MM-dd"
        return it
    }()

    struct Arguments: Codable {
        var query: String
        var freshness: String?
    }

    struct Result: ChatGPTFunctionResult {
        var result: WebSearchResult

        var botReadableContent: String {
            result.webPages.enumerated().map {
                let (index, page) = $0
                return """
                \(index + 1). \(page.title) \(page.urlString)
                \(page.snippet)
                """
            }.joined(separator: "\n")
        }
        
        var userReadableContent: ChatGPTFunctionResultUserReadableContent {
            .text(botReadableContent)
        }
    }

    let maxTokens: Int

    var name: String {
        "searchWeb"
    }

    var description: String {
        "Useful for when you need to answer questions about latest information."
    }

    var argumentSchema: JSONSchemaValue {
        let today = Self.dateFormatter.string(from: Date())
        return [
            .type: "object",
            .properties: [
                "query": [
                    .type: "string",
                    .description: "the search query",
                ],
                "freshness": [
                    .type: "string",
                    .description: .string(
                        "limit the search result to a specific range, use only when I ask the question about current events. Today is \(today). Format: yyyy-MM-dd..yyyy-MM-dd"
                    ),
                    .examples: ["1919-10-20..1988-10-20"],
                ],
            ],
            .required: ["query"],
        ]
    }

    func prepare(reportProgress: @escaping ReportProgress) async {
        await reportProgress("Searching..")
    }

    func call(
        arguments: Arguments,
        reportProgress: @escaping ReportProgress
    ) async throws -> Result {
        await reportProgress("Searching \(arguments.query)")

        do {
            let search = WebSearchService(provider: .userPreferred)

            let result = try await search.search(query: arguments.query)

            await reportProgress("""
            Finish searching \(arguments.query)
            \(
                result.webPages
                    .map { "- [\($0.title)](\($0.urlString))" }
                    .joined(separator: "\n")
            )
            """)

            return .init(result: result)
        } catch {
            await reportProgress("Failed searching: \(error.localizedDescription)")
            throw error
        }
    }
}


import BingSearchService
import ChatBasic
import Foundation
import OpenAIService
import Preferences

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
        var result: BingSearchResult

        var botReadableContent: String {
            result.webPages.value.enumerated().map {
                let (index, page) = $0
                return """
                \(index + 1). \(page.name) \(page.url)
                \(page.snippet)
                """
            }.joined(separator: "\n")
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
            let bingSearch = BingSearchService(
                subscriptionKey: UserDefaults.shared.value(for: \.bingSearchSubscriptionKey),
                searchURL: UserDefaults.shared.value(for: \.bingSearchEndpoint)
            )

            let result = try await bingSearch.search(
                query: arguments.query,
                numberOfResult: maxTokens > 5000 ? 5 : 3,
                freshness: arguments.freshness
            )

            await reportProgress("""
            Finish searching \(arguments.query)
            \(
                result.webPages.value
                    .map { "- [\($0.name)](\($0.url))" }
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


import BingSearchService
import ChatContextCollector
import Foundation
import OpenAIService
import Preferences
import SuggestionModel

public struct WebChatContextCollector: ChatContextCollector {
    public init() {}

    public func generateContext(
        history: [ChatMessage],
        scopes: Set<String>,
        content: String
    ) -> ChatContext? {
        guard scopes.contains("web") else { return nil }
        return .init(
            systemPrompt: "You prefer to answer questions with latest latest on the internet.",
            functions: [
                SearchFunction(),
            ]
        )
    }

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
                            "limit the search result to a specific range, use only when user ask the question about current events. Today is \(today). Format: yyyy-MM-dd..yyyy-MM-dd"
                        ),
                        .examples: ["1919-10-20..1988-10-20"],
                    ],
                ],
                .required: ["query"],
            ]
        }

        func message(at phase: ChatGPTFunctionCallPhase) -> String {
            func parseArgument(_ string: String) throws -> Arguments {
                try JSONDecoder().decode(Arguments.self, from: string.data(using: .utf8) ?? Data())
            }

            switch phase {
            case .detected:
                return "Searching.."
            case let .processing(argumentsJsonString):
                do {
                    let arguments = try parseArgument(argumentsJsonString)
                    return "Searching \(arguments.query)"
                } catch {
                    return "Searching.."
                }
            case let .ended(argumentsJsonString, result):
                do {
                    let arguments = try parseArgument(argumentsJsonString)
                    if let result = result as? Result {
                        return """
                        Finish searching \(arguments.query)
                        \(
                            result.result.webPages.value
                                .map { "- [\($0.name)](\($0.url))" }
                                .joined(separator: "\n")
                        )
                        """
                    }
                    return "Finish searching \(arguments.query)"
                } catch {
                    return "Finish searching"
                }
            case let .error(argumentsJsonString, _):
                do {
                    let arguments = try parseArgument(argumentsJsonString)
                    return "Failed searching \(arguments.query)"
                } catch {
                    return "Failed searching"
                }
            }
        }

        func call(arguments: Arguments) async throws -> Result {
            let bingSearch = BingSearchService(
                subscriptionKey: UserDefaults.shared.value(for: \.bingSearchSubscriptionKey),
                searchURL: UserDefaults.shared.value(for: \.bingSearchEndpoint)
            )
            let result = try await bingSearch.search(
                query: arguments.query,
                numberOfResult: UserDefaults.shared.value(for: \.chatGPTMaxToken) > 5000 ? 5 : 3,
                freshness: arguments.freshness
            )

            let content = result.webPages.value.enumerated().map {
                let (index, page) = $0
                return """
                \(index + 1). \(page.name) \(page.url)
                \(page.snippet)
                """
            }.joined(separator: "\n")

            return .init(result: result)
        }
    }
}


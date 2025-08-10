import Foundation

struct BingSearchResult: Codable {
    var webPages: WebPages

    struct WebPages: Codable {
        var webSearchUrl: String
        var totalEstimatedMatches: Int
        var value: [WebPageValue]

        struct WebPageValue: Codable {
            var id: String
            var name: String
            var url: String
            var displayUrl: String
            var snippet: String
        }
    }
}

struct BingSearchResponseError: Codable, Error, LocalizedError {
    struct E: Codable {
        var code: String?
        var message: String?
    }

    var error: E
    var errorDescription: String? { error.message }
}

enum BingSearchError: Error, LocalizedError {
    case searchURLFormatIncorrect(String)
    case subscriptionKeyNotAvailable

    var errorDescription: String? {
        switch self {
        case let .searchURLFormatIncorrect(url):
            return "The search URL format is incorrect: \(url)"
        case .subscriptionKeyNotAvailable:
            return "Bing search subscription key is not available, please set it up in the service tab."
        }
    }
}

struct BingSearchService: SearchService {
    var subscriptionKey: String
    var searchURL: String

    init(subscriptionKey: String, searchURL: String) {
        self.subscriptionKey = subscriptionKey
        self.searchURL = searchURL
    }

    func search(query: String) async throws -> WebSearchResult {
        let result = try await search(query: query, numberOfResult: 10)
        return WebSearchResult(webPages: result.webPages.value.map {
            WebSearchResult.WebPage(
                urlString: $0.url,
                title: $0.name,
                snippet: $0.snippet
            )
        })
    }

    func search(
        query: String,
        numberOfResult: Int,
        freshness: String? = nil
    ) async throws -> BingSearchResult {
        guard !subscriptionKey.isEmpty else { throw BingSearchError.subscriptionKeyNotAvailable }
        guard let url = URL(string: searchURL)
        else { throw BingSearchError.searchURLFormatIncorrect(searchURL) }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            .init(name: "q", value: query),
            .init(name: "count", value: String(numberOfResult)),
            freshness.map { .init(name: "freshness", value: $0) },
        ].compactMap { $0 }
        var request = URLRequest(url: components?.url ?? url)
        request.httpMethod = "GET"
        request.addValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")

        let (data, _) = try await URLSession.shared.data(for: request)
        do {
            let result = try JSONDecoder().decode(BingSearchResult.self, from: data)
            return result
        } catch {
            let e = try JSONDecoder().decode(BingSearchResponseError.self, from: data)
            throw e
        }
    }
}


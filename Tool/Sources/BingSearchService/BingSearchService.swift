import Foundation

public struct BingSearchResult: Codable {
    public var webPages: WebPages

    public struct WebPages: Codable {
        public var webSearchUrl: String
        public var totalEstimatedMatches: Int
        public var value: [WebPageValue]

        public struct WebPageValue: Codable {
            public var id: String
            public var name: String
            public var url: String
            public var displayUrl: String
            public var snippet: String
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
            return "The I didn't provide a subscription key to use Bing search."
        }
    }
}

public struct BingSearchService {
    public var subscriptionKey: String
    public var searchURL: String

    public init(subscriptionKey: String, searchURL: String) {
        self.subscriptionKey = subscriptionKey
        self.searchURL = searchURL
    }

    public func search(
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


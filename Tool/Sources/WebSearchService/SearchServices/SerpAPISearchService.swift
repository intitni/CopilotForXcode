import Foundation

struct SerpAPIResponse: Codable {
    var organic_results: [OrganicResult]

    struct OrganicResult: Codable {
        var position: Int?
        var title: String?
        var link: String?
        var snippet: String?

        func toWebSearchResult() -> WebSearchResult.WebPage? {
            guard let link, let title else { return nil }
            return WebSearchResult.WebPage(urlString: link, title: title, snippet: snippet ?? "")
        }
    }

    func toWebSearchResult() -> WebSearchResult {
        return WebSearchResult(webPages: organic_results.compactMap { $0.toWebSearchResult() })
    }
}

struct SerpAPISearchService: SearchService {
    let engine: WebSearchProvider.SerpAPIEngine
    let endpoint: URL = .init(string: "https://serpapi.com/search.json")!
    let apiKey: String

    init(engine: WebSearchProvider.SerpAPIEngine, apiKey: String) {
        self.engine = engine
        self.apiKey = apiKey
    }

    func search(query: String) async throws -> WebSearchResult {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "engine", value: engine.rawValue),
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }

        request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Parse the response into WebSearchResult
        let decoder = JSONDecoder()

        do {
            let searchResponse = try decoder.decode(SerpAPIResponse.self, from: data)
            return searchResponse.toWebSearchResult()
        } catch {
            throw error
        }
    }
}


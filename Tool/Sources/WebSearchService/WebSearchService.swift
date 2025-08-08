import Foundation
import Preferences

public enum WebSearchProvider {
    public enum SerpAPIEngine: String {
        case google
        case baidu
        case bing
        case duckDuckGo = "duckduckgo"
    }

    public enum HeadlessBrowserEngine: String {
        case google
        case baidu
    }

    case serpAPI(SerpAPIEngine, apiKey: String)
    case headlessBrowser(HeadlessBrowserEngine)

    public static var userPreferred: WebSearchProvider {
        switch UserDefaults.shared.value(for: \.searchProvider) {
        case .headlessBrowser:
            return .headlessBrowser(.init(
                rawValue: UserDefaults.shared.value(for: \.headlessBrowserEngine)
                    .rawValue
            ) ?? .google)
        case .serpAPI:
            return .serpAPI(.init(
                rawValue: UserDefaults.shared.value(for: \.headlessBrowserEngine)
                    .rawValue
            ) ?? .google, apiKey: "")
        }
    }
}

public struct WebSearchResult {
    public struct WebPage {
        public var urlString: String
        public var title: String
        public var snippet: String
    }

    public var webPages: [WebPage]
}

public protocol SearchService {
    func search(query: String) async throws -> WebSearchResult
}

public struct WebSearchService {
    let service: SearchService

    init(service: SearchService) {
        self.service = service
    }

    public init(provider: WebSearchProvider) {
        switch provider {
        case let .serpAPI(engine, apiKey):
            service = SerpAPISearchService(engine: engine, apiKey: apiKey)
        case let .headlessBrowser(engine):
            fatalError()
        }
    }

    public func search(query: String) async throws -> WebSearchResult {
        return try await service.search(query: query)
    }
}


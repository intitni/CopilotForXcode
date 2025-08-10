import Foundation
import SwiftSoup
import WebKit
import WebScrapper

struct HeadlessBrowserSearchService: SearchService {
    let engine: WebSearchProvider.HeadlessBrowserEngine

    func search(query: String) async throws -> WebSearchResult {
        let queryEncoded = query
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = switch engine {
        case .google:
            URL(string: "https://www.google.com/search?q=\(queryEncoded)")!
        case .baidu:
            URL(string: "https://www.baidu.com/s?wd=\(queryEncoded)")!
        case .duckDuckGo:
            URL(string: "https://duckduckgo.com/?q=\(queryEncoded)")!
        case .bing:
            URL(string: "https://www.bing.com/search?q=\(queryEncoded)")!
        }

        let scrapper = await WebScrapper()
        let html = try await scrapper.fetch(url: url) { document in
            switch engine {
            case .google:
                return GoogleSearchResultParser.validate(document: document)
            case .baidu:
                return BaiduSearchResultParser.validate(document: document)
            case .duckDuckGo:
                return DuckDuckGoSearchResultParser.validate(document: document)
            case .bing:
                return BingSearchResultParser.validate(document: document)
            }
        }

        switch engine {
        case .google:
            return try GoogleSearchResultParser.parse(html: html)
        case .baidu:
            return await BaiduSearchResultParser.parse(html: html)
        case .duckDuckGo:
            return DuckDuckGoSearchResultParser.parse(html: html)
        case .bing:
            return BingSearchResultParser.parse(html: html)
        }
    }
}

enum GoogleSearchResultParser {
    static func validate(document: SwiftSoup.Document) -> Bool {
        guard let _ = try? document.select("#rso").first
        else { return false }
        return true
    }

    static func parse(html: String) throws -> WebSearchResult {
        let document = try SwiftSoup.parse(html)
        let searchResult = try document.select("#rso").first

        guard let searchResult else { return .init(webPages: []) }

        var results: [WebSearchResult.WebPage] = []
        for element in searchResult.children() {
            if let title = try? element.select("h3").text(),
               let link = try? element.select("a").attr("href"),
               !link.isEmpty,
               // A magic class name.
               let snippet = try? element.select("div.VwiC3b").first()?.text()
               ?? element.select("span.st").first()?.text()
            {
                results.append(WebSearchResult.WebPage(
                    urlString: link,
                    title: title,
                    snippet: snippet
                ))
            }
        }

        return WebSearchResult(webPages: results)
    }
}

enum BaiduSearchResultParser {
    static func validate(document: SwiftSoup.Document) -> Bool {
        return (try? document.select("#content_left").first()) != nil
    }
    
    static func getRealLink(from baiduLink: String) async -> String {
        guard let url = URL(string: baiduLink) else {
            return baiduLink
        }

        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let redirectCapturer = RedirectCapturer()
        let session = URLSession(
            configuration: config,
            delegate: redirectCapturer,
            delegateQueue: nil
        )

        do {
            let _ = try await session.data(for: request)

            if let finalURL = redirectCapturer.finalURL {
                return finalURL.absoluteString
            }

            return baiduLink
        } catch {
            return baiduLink
        }
    }

    class RedirectCapturer: NSObject, URLSessionTaskDelegate {
        var finalURL: URL?

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            finalURL = request.url
            completionHandler(request)
        }
    }
    static func parse(html: String) async -> WebSearchResult {
        let document = try? SwiftSoup.parse(html)
        let elements = try? document?.select("#content_left").first()?.children()

        var results: [WebSearchResult.WebPage] = []
        if let elements = elements {
            for element in elements {
                if let titleElement = try? element.select("h3").first(),
                   let link = try? element.select("a").attr("href"),
                   link.hasPrefix("http")
                {
                    let realLink = await getRealLink(from: link)
                    let title = (try? titleElement.text()) ?? ""
                    let snippet = {
                        let abstract = try? element.select("div[data-module=\"abstract\"]").text()
                        if let abstract, !abstract.isEmpty {
                            return abstract
                        }
                        return (try? titleElement.nextElementSibling()?.text()) ?? ""
                    }()
                    results.append(WebSearchResult.WebPage(
                        urlString: realLink,
                        title: title,
                        snippet: snippet
                    ))
                }
            }
        }

        return WebSearchResult(webPages: results)
    }
}

enum DuckDuckGoSearchResultParser {
    static func validate(document: SwiftSoup.Document) -> Bool {
        return (try? document.select(".react-results--main").first()) != nil
    }

    static func parse(html: String) -> WebSearchResult {
        let document = try? SwiftSoup.parse(html)
        let body = document?.body()

        var results: [WebSearchResult.WebPage] = []

        if let reactResults = try? body?.select(".react-results--main") {
            for object in reactResults {
                for element in object.children() {
                    if let linkElement = try? element.select("a[data-testid=\"result-title-a\"]"),
                       let link = try? linkElement.attr("href"),
                       link.hasPrefix("http"),
                       let titleElement = try? element.select("span").first()
                    {
                        let title = (try? titleElement.select("span").first()?.text()) ?? ""
                        let snippet = (
                            try? element.select("[data-result=snippet]").first()?.text()
                        ) ?? ""

                        results.append(WebSearchResult.WebPage(
                            urlString: link,
                            title: title,
                            snippet: snippet
                        ))
                    }
                }
            }
        }

        return WebSearchResult(webPages: results)
    }
}

enum BingSearchResultParser {
    static func validate(document: SwiftSoup.Document) -> Bool {
        return (try? document.select("#b_results").first()) != nil
    }

    static func parse(html: String) -> WebSearchResult {
        let document = try? SwiftSoup.parse(html)
        let searchResults = try? document?.select("#b_results").first()

        var results: [WebSearchResult.WebPage] = []
        if let elements = try? searchResults?.select("li.b_algo") {
            for element in elements {
                if let titleElement = try? element.select("h2").first(),
                   let linkElement = try? titleElement.select("a").first(),
                   let link = try? linkElement.attr("href"),
                   link.hasPrefix("http")
                {
                    let title = (try? titleElement.text()) ?? ""
                    let snippet = {
                        if let it = try? element.select(".b_caption p").first()?.text(),
                           !it.isEmpty { return it }
                        if let it = try? element.select(".b_lineclamp2").first()?.text(),
                           !it.isEmpty { return it }
                        return (try? element.select("p").first()?.text()) ?? ""
                    }()

                    results.append(WebSearchResult.WebPage(
                        urlString: link,
                        title: title,
                        snippet: snippet
                    ))
                }
            }
        }

        return WebSearchResult(webPages: results)
    }
}


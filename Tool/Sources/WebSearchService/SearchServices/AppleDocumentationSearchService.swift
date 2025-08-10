import Foundation
import SwiftSoup
import WebKit
import WebScrapper

struct AppleDocumentationSearchService: SearchService {
    func search(query: String) async throws -> WebSearchResult {
        let queryEncoded = query
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://developer.apple.com/search/?q=\(queryEncoded)")!

        let scrapper = await WebScrapper()
        let html = try await scrapper.fetch(url: url) { document in
            DeveloperDotAppleResultParser.validate(document: document)
        }

        return try DeveloperDotAppleResultParser.parse(html: html)
    }
}

enum DeveloperDotAppleResultParser {
    static func validate(document: SwiftSoup.Document) -> Bool {
        guard let _ = try? document.select("ul.search-results").first
        else { return false }
        return true
    }

    static func parse(html: String) throws -> WebSearchResult {
        let document = try SwiftSoup.parse(html)
        let searchResult = try? document.select("ul.search-results").first

        guard let searchResult else { return .init(webPages: []) }

        var results: [WebSearchResult.WebPage] = []
        for element in searchResult.children() {
            if let titleElement = try? element.select("p.result-title"),
               let link = try? titleElement.select("a").attr("href"),
               !link.isEmpty
            {
                let title = (try? titleElement.text()) ?? ""
                let snippet = (try? element.select("p.result-description").text())
                    ?? (try? element.select("ul.breadcrumb-list").text())
                    ?? ""
                results.append(WebSearchResult.WebPage(
                    urlString: {
                        if link.hasPrefix("/") {
                            return "https://developer.apple.com\(link)"
                        }
                        return link
                    }(),
                    title: title,
                    snippet: snippet
                ))
            }
        }

        return WebSearchResult(webPages: results)
    }
}


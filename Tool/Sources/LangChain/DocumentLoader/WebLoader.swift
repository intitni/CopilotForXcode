import Foundation
import Logger
import SwiftSoup
import WebKit

/// Load the body of a web page.
public struct WebLoader: DocumentLoader {
    enum MetadataKeys {
        static let title = "title"
        static let url = "url"
        static let date = "date"
    }

    var downloadHTML: (_ url: URL) async throws -> (url: URL, html: String) = { url in
        let html = try await WebScrapper().fetch(url: url)
        return (url, html)
    }

    public var urls: [URL]

    public init(urls: [URL]) {
        self.urls = urls
    }

    public init(url: URL) {
        urls = [url]
    }

    public func load() async throws -> [Document] {
        try await withThrowingTaskGroup(of: (url: URL, html: String).self) { group in
            for url in urls {
                group.addTask {
                    try await downloadHTML(url)
                }
            }
            var documents: [Document] = []
            for try await result in group {
                do {
                    let parsed = try SwiftSoup.parse(result.html, result.url.path)

                    let title = (try? parsed.title()) ?? "Untitled"
                    let parsedDocuments = try DefaultLoadContentStrategy().load(
                        parsed,
                        metadata: [
                            MetadataKeys.title: .string(title),
                            MetadataKeys.url: .string(result.url.absoluteString),
                            MetadataKeys.date: .number(Date().timeIntervalSince1970),
                        ]
                    )
                    documents.append(contentsOf: parsedDocuments)
                } catch let Exception.Error(_, message) {
                    Logger.langchain.error(message)
                } catch {
                    Logger.langchain.error(error.localizedDescription)
                }
            }
            return documents
        }
    }
}

protocol LoadWebPageMainContentStrategy {
    func load(_ document: SwiftSoup.Document, metadata: Document.Metadata) throws -> [Document]
}

extension LoadWebPageMainContentStrategy {
    func text(inFirstTag tagName: String, from document: SwiftSoup.Document) -> String? {
        if let tag = try? document.getElementsByTag(tagName).first(),
           let text = try? tag.text()
        {
            return text
        }
        return nil
    }
}

extension WebLoader {
    struct DefaultLoadContentStrategy: LoadWebPageMainContentStrategy {
        func load(
            _ document: SwiftSoup.Document,
            metadata: Document.Metadata
        ) throws -> [Document] {
            if let mainContent = try? {
                if let article = text(inFirstTag: "article", from: document) { return article }
                if let main = text(inFirstTag: "main", from: document) { return main }
                let body = try document.body()?.text()
                return body
            }() {
                return [.init(pageContent: mainContent, metadata: metadata)]
            }
            return []
        }
    }
}

@MainActor
final class WebScrapper: NSObject, WKNavigationDelegate {
    var webView: WKWebView

    let retryLimit: Int
    var webViewDidFinishLoading = false
    var navigationError: (any Error)?

    init(retryLimit: Int = 10) {
        self.retryLimit = retryLimit
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration
            .applicationNameForUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Safari/605.1.15"
        // The web page need the web view to have a size to load correctly.
        let webView = WKWebView(
            frame: .init(x: 0, y: 0, width: 500, height: 500),
            configuration: configuration
        )
        self.webView = webView
        super.init()
        webView.navigationDelegate = self
    }

    func fetch(url: URL) async throws -> String {
        webViewDidFinishLoading = false
        navigationError = nil
        var retryCount = 0
        _ = webView.load(.init(url: url))
        while !webViewDidFinishLoading {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        if let navigationError { throw navigationError }
        while retryCount < retryLimit {
            let html = try await getHTML()
            if !html.isEmpty { return html }
            retryCount += 1
        }

        throw CancellationError()
    }

    nonisolated func webView(_: WKWebView, didFinish _: WKNavigation!) {
        Task { @MainActor in
            self.webViewDidFinishLoading = true
        }
    }

    nonisolated func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            self.navigationError = error
            self.webViewDidFinishLoading = true
        }
    }

    func getHTML() async throws -> String {
        return try await webView.evaluateJavaScript(getHTMLText) as? String ?? ""
    }
}

private let getHTMLText = """
document.documentElement.outerHTML;
"""


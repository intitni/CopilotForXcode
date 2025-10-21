import Foundation
import SwiftSoup
import WebKit

@MainActor
public final class WebScrapper {
    final class NavigationDelegate: NSObject, WKNavigationDelegate {
        weak var scrapper: WebScrapper?

        public nonisolated func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            Task { @MainActor in
                let scrollToBottomScript = "window.scrollTo(0, document.body.scrollHeight);"
                _ = try? await webView.evaluateJavaScript(scrollToBottomScript)
                self.scrapper?.webViewDidFinishLoading = true
            }
        }

        public nonisolated func webView(
            _: WKWebView,
            didFail _: WKNavigation!,
            withError error: Error
        ) {
            Task { @MainActor in
                self.scrapper?.navigationError = error
                self.scrapper?.webViewDidFinishLoading = true
            }
        }
    }

    public var webView: WKWebView

    var webViewDidFinishLoading = false
    var navigationError: (any Error)?
    let navigationDelegate: NavigationDelegate = .init()

    enum WebScrapperError: Error {
        case retry
    }

    public init() async {
        let jsonRuleList = ###"""
        [
          {
            "trigger": {
              "url-filter": ".*",
              "resource-type": ["font"]
            },
            "action": {
              "type": "block"
            }
          },
          {
            "trigger": {
              "url-filter": ".*",
              "resource-type": ["image"]
            },
            "action": {
              "type": "block"
            }
          },
          {
            "trigger": {
              "url-filter": ".*",
              "resource-type": ["media"]
            },
            "action": {
              "type": "block"
            }
          }
        ]
        """###

        let list = try? await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "web-scrapping",
            encodedContentRuleList: jsonRuleList
        )

        let configuration = WKWebViewConfiguration()
        if let list {
            configuration.userContentController.add(list)
        }
        configuration.allowsAirPlayForMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .nonPersistent()
        configuration.applicationNameForUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0.1 Safari/605.1.15"

        if #available(iOS 17.0, macOS 14.0, *) {
            configuration.allowsInlinePredictions = false
        }

        // The web page need the web view to have a size to load correctly.
        let webView = WKWebView(
            frame: .init(x: 0, y: 0, width: 800, height: 5000),
            configuration: configuration
        )
        self.webView = webView
        navigationDelegate.scrapper = self
        webView.navigationDelegate = navigationDelegate
    }

    public func fetch(
        url: URL,
        validate: @escaping (SwiftSoup.Document) -> Bool = { _ in true },
        timeout: TimeInterval = 15,
        retryLimit: Int = 50
    ) async throws -> String {
        webViewDidFinishLoading = false
        navigationError = nil
        var retryCount = 0
        _ = webView.load(.init(url: url))
        while !webViewDidFinishLoading {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let deadline = Date().addingTimeInterval(timeout)
        if let navigationError { throw navigationError }
        while retryCount < retryLimit, Date() < deadline {
            if let html = try? await getHTML(), !html.isEmpty,
               let document = try? SwiftSoup.parse(html, url.path),
               validate(document)
            {
                return html
            }
            retryCount += 1
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        enum Error: Swift.Error, LocalizedError {
            case failToValidate

            var errorDescription: String? {
                switch self {
                case .failToValidate:
                    return "Failed to validate the HTML content within the given timeout and retry limit."
                }
            }
        }
        throw Error.failToValidate
    }

    func getHTML() async throws -> String {
        do {
            let isReady = try await webView.evaluateJavaScript(checkIfReady) as? Bool ?? false
            if !isReady { throw WebScrapperError.retry }
            return try await webView.evaluateJavaScript(getHTMLText) as? String ?? ""
        } catch {
            throw WebScrapperError.retry
        }
    }
}

private let getHTMLText = """
document.documentElement.outerHTML;
"""

private let checkIfReady = """
document.readyState === "ready" || document.readyState === "complete";
"""


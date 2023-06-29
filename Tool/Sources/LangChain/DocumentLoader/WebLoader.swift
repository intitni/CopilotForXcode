import Foundation
import Logger
import SwiftSoup

public struct WebLoader: DocumentLoader {
    var downloadHTML: (_ url: URL) async throws -> (url: URL, html: String) = { url in
        let session = URLSession.shared
        let (data, _) = try await session.data(for: .init(url: url))
        let html = String(data: data, encoding: .utf8) ?? ""
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
                    let body = try DefaultLoadContentStrategy().load(parsed)

                    if let body = body {
                        let doc = Document(pageContent: body, metadata: [
                            "title": .string(title),
                            "url": .string(result.url.absoluteString),
                            "date": .number(Date().timeIntervalSince1970),
                        ])
                        documents.append(doc)
                    }
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
    func load(_ document: SwiftSoup.Document) throws -> String?
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
        func load(_ document: SwiftSoup.Document) throws -> String? {
            if let article = text(inFirstTag: "article", from: document) { return article }
            if let main = text(inFirstTag: "main", from: document) { return main }
            let body = try document.body()?.text()
            return body
        }
    }
}


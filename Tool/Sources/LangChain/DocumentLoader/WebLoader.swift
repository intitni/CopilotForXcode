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

                    let body = try parsed.body()?.text()
                    let title = (try? parsed.title()) ?? "Untitled"
                    
                    if let body = body {
                        let doc = Document(pageContent: body, metadata: [
                            "title": title,
                            "filename": result.url.lastPathComponent,
                            "extension": result.url.pathExtension,
                            "contentModificationDate": (try? result.url
                                .resourceValues(forKeys: [.contentModificationDateKey])
                                .contentModificationDate) ?? Date(),
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


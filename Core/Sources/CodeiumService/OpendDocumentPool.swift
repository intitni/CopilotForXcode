import Foundation

private let maxSize: Int = 1_000_000 // Byte

actor OpenedDocumentPool {
    var openedDocuments = [URL: OpenedDocument]()

    func getOtherDocuments(exceptURL: URL) -> [OpenedDocument] {
        let ordered = openedDocuments.values.sorted { $0.updateTime > $1.updateTime }
        var documents = [OpenedDocument]()
        var size = 0
        for document in ordered where document.url != exceptURL {
            size += document.size
            if size > maxSize {
                break
            }
            documents.append(document)
        }

        return documents
    }

    func openDocument(url: URL, relativePath: String, content: String) {
        let document = OpenedDocument(url: url, relativePath: relativePath, content: content)
        openedDocuments[url] = document
    }

    func updateDocument(url: URL, relativePath: String, content: String) {
        if let document = openedDocuments[url] {
            document.update(content: content)
        } else {
            openDocument(url: url, relativePath: relativePath, content: content)
        }
    }

    func closeDocument(url: URL) {
        openedDocuments[url] = nil
    }
}

final class OpenedDocument {
    var url: URL
    var relativePath: String
    var updateTime: Date
    var content: String
    var size: Int

    public init(url: URL, relativePath: String, content: String) {
        self.url = url
        self.relativePath = relativePath
        updateTime = Date()
        size = content.utf8.count
        if size > maxSize {
            self.content = ""
        } else {
            self.content = content
        }
    }

    func update(content: String) {
        updateTime = Date()
        size = content.utf8.count
        if size > maxSize {
            self.content = ""
        } else {
            self.content = content
        }
    }
}


import Foundation
import USearch

/// A temporary USearch index for small and temporary documents.
public class TemporaryUSearch {
    public let identifier: String
    let index: USearchIndex
    var documents: [UInt32: Document] = [:]

    public init(identifier: String) {
        self.identifier = identifier
        index = USearchIndex.make(
            metric: .cos,
            dimensions: 1536, // text-embedding-ada-002
            connectivity: 16,
            quantization: .F32
        )
    }

    /// Load a USearch index if found.
    public static func load(identifier: String) -> TemporaryUSearch? {
        let it = TemporaryUSearch(identifier: identifier)
        do {
            try it.load()
            return it
        } catch {
            return nil
        }
    }

    /// Create a readonly USearch instance if the index is found.
    public static func view(identifier: String) -> TemporaryUSearch? {
        let it = TemporaryUSearch(identifier: identifier)
        do {
            try it.view()
            return it
        } catch {
            return nil
        }
    }

    public func save() {
        index.save(path: Self.indexURLFromIdentifier(identifier).path)
        if let documentsData = try? JSONEncoder().encode(documents) {
            FileManager.default.createFile(
                atPath: Self.documentURLFromIdentifier(identifier).path,
                contents: documentsData,
                attributes: nil
            )
        }
    }

    public func search(embeddings: [Float], count: Int, threshold: Float = 0.1) -> [Document] {
        let embeddings = embeddings.map { Float32($0) }[...]
        let result = index.search(vector: embeddings, count: count)
        var matches = [Document]()
        for (index, distance) in zip(result.0, result.1) {
            if let document = documents[index], distance < threshold {
                matches.append(document)
            }
        }
        return matches
    }

    public func clear() {
        index.clear()
        documents = [:]
    }

    public func set(_ documents: [EmbeddedDocument]) {
        clear()
        for (i, document) in documents.enumerated() {
            let embeddings = document.embeddings.map { Float32($0) }[...]
            index.add(label: UInt32(i), vector: embeddings)
            self.documents[UInt32(i)] = document.document
        }
        save()
    }

    enum LoadError: Error {
        case indexNotFound
        case documentsNotFound
    }

    func load() throws {
        let indexURL = Self.indexURLFromIdentifier(identifier)
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw LoadError.indexNotFound
        }
        index.load(path: indexURL.path)
        guard let documentsData = FileManager.default.contents(
            atPath: Self.documentURLFromIdentifier(identifier).path
        ) else {
            throw LoadError.documentsNotFound
        }
        let docs = try JSONDecoder().decode([UInt32: Document].self, from: documentsData)
        documents = docs
    }

    func view() throws {
        let indexURL = Self.indexURLFromIdentifier(identifier)
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw LoadError.indexNotFound
        }
        index.view(path: indexURL.path)
        guard let documentsData = FileManager.default.contents(
            atPath: Self.documentURLFromIdentifier(identifier).path
        ) else {
            throw LoadError.documentsNotFound
        }
        let docs = try JSONDecoder().decode([UInt32: Document].self, from: documentsData)
        documents = docs
    }
}

extension TemporaryUSearch {
    static func indexURLFromIdentifier(_ identifier: String) -> URL {
        let cacheDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
        let url = cacheDirectory
            .appendingPathComponent("CopilotForXcode-USearchIndex-" + identifier + ".usearch")
        return url
    }

    static func documentURLFromIdentifier(_ identifier: String) -> URL {
        let cacheDirectory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first!
        let url = cacheDirectory
            .appendingPathComponent("CopilotForXcode-USearchDocument-" + identifier + ".usearch")
        return url
    }
}


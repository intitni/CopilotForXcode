import CryptoKit
import Foundation
import USearchIndex

@globalActor
private actor TemporaryUSearchActor {
    static let shared = TemporaryUSearchActor()
}

/// A temporary USearch index for small and temporary documents.
public actor TemporaryUSearch: VectorStore {
    struct LabeledDocument: Codable {
        let label: USearchLabel
        let document: Document
    }

    public let identifier: String
    let index: USearchIndex
    var documents: [USearchLabel: LabeledDocument] = [:]

    public init(identifier: String, dimensions: Int = 1536 /* text-embedding-ada-002 */ ) {
        self.identifier = calculateMD5Hash(identifier)
        index = .init(
            metric: .IP,
            dimensions: UInt32(dimensions),
            connectivity: 16,
            quantization: .F32
        )
    }

    /// Load a USearch index if found.
    public static func load(identifier: String) async -> TemporaryUSearch? {
        let it = TemporaryUSearch(identifier: identifier)
        do {
            try await it.load()
            return it
        } catch {
            return nil
        }
    }

    /// Create a readonly USearch instance if the index is found.
    public static func view(identifier: String) async -> TemporaryUSearch? {
        let it = TemporaryUSearch(identifier: identifier)
        do {
            try await it.view()
            return it
        } catch {
            return nil
        }
    }

    public func save() async throws {
        try await index.save(path: Self.indexURLFromIdentifier(identifier).path)
        let labeledDocuments: [LabeledDocument] = Array(documents.values)
        if let documentsData = try? JSONEncoder().encode(labeledDocuments) {
            FileManager.default.createFile(
                atPath: Self.documentURLFromIdentifier(identifier).path,
                contents: documentsData,
                attributes: nil
            )
        }
    }

    public func searchWithDistance(
        embeddings: [Float],
        count: Int
    ) async throws -> [(document: Document, distance: Float)] {
        let result = try await index.search(vector: embeddings, count: count)
        var matches = [(document: Document, distance: Float)]()
        for (index, distance) in result {
            if let document = documents[index] {
                matches.append((document.document, distance))
            }
        }
        return matches
    }

    public func clear() async throws {
        try await index.clear()
        documents = [:]
    }

    public func add(_ documents: [EmbeddedDocument]) async throws {
        let lastIndex = self.documents.keys.max() ?? 0
        for (i, document) in documents.enumerated() {
            let key = Int(lastIndex) + i + 1
            let label = USearchLabel(key)
            let embeddings = document.embeddings
            try await index.add(label: label, vector: embeddings)
            self.documents[label] = .init(label: label, document: document.document)
        }
        try await save()
    }

    public func set(_ documents: [EmbeddedDocument]) async throws {
        let items = documents.enumerated().map { (USearchLabel(UInt32($0)), $1.embeddings) }
        self.documents = [:]
        try await index.set(items: items)
        for (i, document) in documents.enumerated() {
            let label = USearchLabel(i)
            self.documents[label] = .init(label: label, document: document.document)
        }
        try await save()
    }

    enum LoadError: Error {
        case indexNotFound
        case documentsNotFound
    }

    func load() async throws {
        let indexURL = Self.indexURLFromIdentifier(identifier)
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw LoadError.indexNotFound
        }
        try await index.load(path: indexURL.path)
        guard let documentsData = FileManager.default.contents(
            atPath: Self.documentURLFromIdentifier(identifier).path
        ) else {
            throw LoadError.documentsNotFound
        }
        let docs = try JSONDecoder().decode([LabeledDocument].self, from: documentsData)
        documents = [:]
        for doc in docs {
            documents[doc.label] = doc
        }
    }

    func view() async throws {
        let indexURL = Self.indexURLFromIdentifier(identifier)
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw LoadError.indexNotFound
        }
        try await index.view(path: indexURL.path)
        guard let documentsData = FileManager.default.contents(
            atPath: Self.documentURLFromIdentifier(identifier).path
        ) else {
            throw LoadError.documentsNotFound
        }
        let docs = try JSONDecoder().decode([LabeledDocument].self, from: documentsData)
        documents = [:]
        for doc in docs {
            documents[doc.label] = doc
        }
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

private func calculateMD5Hash(_ text: String) -> String {
    let hash = Insecure.MD5.hash(data: text.data(using: .utf8) ?? Data())
    return hash.map { String(format: "%02hhx", $0) }.joined()
}


import Foundation
import USearch
import USearchObjective

@globalActor
private actor TemporaryUSearchActor {
    static let shared = TemporaryUSearchActor()
}

#warning(
    "It's not working yet because of a bug in USearch https://github.com/unum-cloud/usearch/issues/131"
)

/// A temporary USearch index for small and temporary documents.
public actor TemporaryUSearch: VectorStore {
    public let identifier: String
    let index: USearchIndex
    var documents: [UInt32: Document] = [:]
    var isViewOnly: Bool = false

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

    public func searchWithDistance(
        embeddings: [Float],
        count: Int
    ) async throws -> [(document: Document, distance: Float)] {
        let embeddings = embeddings.map { Float32($0) }[...]
        let result = index.search(vector: embeddings, count: count)
        var matches = [(document: Document, distance: Float)]()
        for (index, distance) in zip(result.0, result.1) {
            if let document = documents[index] {
                matches.append((document, distance))
            }
        }
        return matches
    }

    public func clear() {
        guard !isViewOnly else { return }
        index.clear()
        documents = [:]
    }

    public func add(_ documents: [EmbeddedDocument]) async throws {
        guard !isViewOnly else { return }
        let lastIndex = self.documents.keys.max() ?? 0
        for (i, document) in documents.enumerated() {
            let key = lastIndex + UInt32(i) + 1
            let embeddings = document.embeddings.map { Float32($0) }[...]
            index.add(label: key, vector: embeddings)
            self.documents[key] = document.document
        }
        save()
    }

    public func set(_ documents: [EmbeddedDocument]) async throws {
        guard !isViewOnly else { return }
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
        isViewOnly = true
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


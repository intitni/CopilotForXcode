import Foundation
import USearchIndex
import XCTest

import USearch

@testable import LangChain

class TemporaryUSearchTests: XCTestCase {
    func test_usearch() async throws {
        let index = USearchIndex(
            metric: USearchMetric.l2sq,
            dimensions: 4,
            connectivity: 8,
            quantization: USearchScalar.F32
        )
        let vectorA: [Float] = [0.3, 0.5, 1.2, 1.4]
        let vectorB: [Float] = [0.4, 0.2, 1.2, 1.1]
        try await index.clear()
        try await index.add(label: 42, vector: vectorA)
        try await index.add(label: 43, vector: vectorB)

        let results = try await index.search(vector: vectorA, count: 10)
        assert(results[0].label == 42)
    }

    func test_setting_data() async throws {
        let identifier = "hello-world"
        let store = TemporaryUSearch(identifier: identifier)
        try await store.set(EmbeddingData.data.map { datum in
            .init(
                document: .init(pageContent: datum.text, metadata: [:]),
                embeddings: datum.embedding
            )
        })
    }
}


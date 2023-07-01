public enum OpenAIEmbeddingModel: String, CaseIterable {
    case textEmbeddingAda002 = "text-embedding-ada-002"
}

public extension OpenAIEmbeddingModel {
    var maxToken: Int {
        switch self {
        case .textEmbeddingAda002:
            return 8191
        }
    }
}


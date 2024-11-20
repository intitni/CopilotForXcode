public enum OpenAIEmbeddingModel: String, CaseIterable {
    case textEmbedding3Small = "text-embedding-3-small"
    case textEmbedding3Large = "text-embedding-3-large"
    case textEmbeddingAda002 = "text-embedding-ada-002"
}

public extension OpenAIEmbeddingModel {
    var maxToken: Int {
        switch self {
        case .textEmbeddingAda002:
            return 8191
        case .textEmbedding3Small:
            return 8191
        case .textEmbedding3Large:
            return 8191
        }
    }
    
    var dimensions: Int {
        switch self {
        case .textEmbeddingAda002:
            return 1536
        case .textEmbedding3Small:
            return 1536
        case .textEmbedding3Large:
            return 3072
        }
    }
}


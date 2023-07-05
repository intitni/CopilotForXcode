import Foundation
import LangChain
import OpenAIService
import Preferences

struct QueryWebsiteFunction: ChatGPTFunction {
    struct Arguments: Codable {
        var query: String
        var urls: [String]
    }

    struct Result: ChatGPTFunctionResult {
        var relevantDocuments: [Document]

        var botReadableContent: String {
            // don't forget to remove overlaps
            if relevantDocuments.isEmpty {
                return "No relevant information found"
            }
            return relevantDocuments.map(\.pageContent).joined(separator: "\n\n")
        }
    }

    var reportProgress: (String) async -> Void = { _ in }

    var name: String {
        "queryWebsite"
    }

    var description: String {
        "Useful for when you need to answer a question using information from a website."
    }

    var argumentSchema: JSONSchemaValue {
        return [
            .type: "object",
            .properties: [
                "query": [
                    .type: "string",
                    .description: "things you want to know about the website",
                ],
                "urls": [
                    .type: "array",
                    .description: "urls of the website, you can use urls appearing in the conversation",
                    .items: [
                        .type: "string",
                    ],
                ],
            ],
            .required: ["query", "urls"],
        ]
    }

    func prepare() async {
        await reportProgress("Reading..")
    }

    func call(arguments: Arguments) async throws -> Result {
        throw CancellationError()
//        do {
//            throw CancellationError()
//            let embedding = OpenAIEmbedding(
//                configuration: UserPreferenceEmbeddingConfiguration()
//            )
//
//            let queryEmbeddings = try await embedding.embed(query: arguments.query)
//            let searchCount = UserDefaults.shared.value(for: \.chatGPTMaxToken) > 5000 ? 3 : 2
//
//            let result = try await withThrowingTaskGroup(
//                of: [(document: Document, distance: Float)].self
//            ) { group in
//                for urlString in arguments.urls {
//                    guard let url = URL(string: urlString) else { continue }
//                    group.addTask {
//                        if let database = await TemporaryUSearch.view(identifier: urlString) {
//                            return try await database.searchWithDistance(
//                                embeddings: queryEmbeddings,
//                                count: searchCount
//                            )
//                        }
//                        // 1. grab the website content
//                        await reportProgress("Loading \(url)..")
//                        print("== load \(url)")
//                        let loader = WebLoader(urls: [url])
//                        let documents = try await loader.load()
//                        await reportProgress("Processing \(url)..")
//                        print("== loaded \(url), documents: \(documents.count)")
//                        // 2. split the content
//                        let splitter = RecursiveCharacterTextSplitter(
//                            chunkSize: 1000,
//                            chunkOverlap: 100
//                        )
//                        let splitDocuments = try await splitter.transformDocuments(documents)
//                        print("== split \(url), documents: \(splitDocuments.count)")
//                        // 3. embedding and store in db
//                        await reportProgress("Embedding \(url)..")
//                        let embeddedDocuments = try await embedding.embed(documents: splitDocuments)
//                        print("== embedded \(url)")
//                        let database = TemporaryUSearch(identifier: urlString)
//                        try await database.set(embeddedDocuments)
//                        print("== save to database \(url)")
//                        let result = try await database.searchWithDistance(
//                            embeddings: queryEmbeddings,
//                            count: searchCount
//                        )
//                        print("== result of \(url): \(result)")
//                        return result
//                    }
//                }
//
//                var all = [(document: Document, distance: Float)]()
//                for try await result in group {
//                    all.append(contentsOf: result)
//                }
//                await reportProgress("Finish reading websites.")
//                return all
//                    .sorted { $0.distance < $1.distance }
//                    .prefix(searchCount)
//            }
//
//            return .init(relevantDocuments: result.map(\.document))
//        } catch {
//            await reportProgress("Failed reading websites.")
//            throw error
//        }
    }
}


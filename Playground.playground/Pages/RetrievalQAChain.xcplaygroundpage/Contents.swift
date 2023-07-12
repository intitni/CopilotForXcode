import AppKit
import LangChain
import OpenAIService
import PlaygroundSupport
import SwiftUI

struct QAForm: View {
    @State var intermediateAnswers = [RefineDocumentChain.IntermediateAnswer]()
    @State var answer: String = ""
    @State var question: String = "What is Swift macros?"
    @State var isProcessing: Bool = false
    @State var url: String = "https://developer.apple.com/documentation/swift/applying-macros"

    var body: some View {
        Form {
            Section(header: Text("Input")) {
                TextField("URL", text: $url)
                TextField("Question", text: $question)
                Button("Ask") {
                    Task {
                        do {
                            try await ask()
                        } catch {
                            answer = error.localizedDescription
                        }
                    }
                }
                .disabled(isProcessing)
            }
            Section(header: Text("Answer")) {
                Text(answer)
            }
            Section(header: Text("Intermediate Answers")) {
                ForEach(0..<intermediateAnswers.endIndex, id: \.self) { index in
                    let answer = intermediateAnswers[index]
                    VStack {
                        Text(answer.answer)
                        Text("Score: \(answer.score)")
                        Text("Needs more context: \(answer.more ? "Yes" : "No")")
                        Divider()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    func ask() async throws {
        intermediateAnswers = []
        isProcessing = true
        defer { isProcessing = false }
        guard let url = URL(string: url) else {
            answer = "Invalid URL"
            return
        }
        let embeddingConfiguration = UserPreferenceEmbeddingConfiguration().overriding()
        let embedding = OpenAIEmbedding(configuration: embeddingConfiguration)
        let store: VectorStore = try await {
            if let store = await TemporaryUSearch.view(identifier: url.absoluteString) {
                return store
            } else {
                let webLoader = WebLoader(urls: [url])
                let store = TemporaryUSearch(identifier: url.absoluteString)
                let webDocuments = try await webLoader.load()
                let splitter = RecursiveCharacterTextSplitter(
                    chunkSize: 1000,
                    chunkOverlap: 100
                )
                let splitDocuments = try await splitter.transformDocuments(webDocuments)
                let embeddedDocuments = try await embedding.embed(documents: splitDocuments)
                try await store.set(embeddedDocuments)
                return store
            }
        }()

        let qa = RetrievalQAChain(
            vectorStore: store,
            embedding: embedding
        )
        answer = try await qa.run(
            question,
            callbackManagers: [
                .init {
                    $0.on(CallbackEvents.RetrievalQADidGenerateIntermediateAnswer.self) {
                        intermediateAnswers.append($0)
                    }
                },
            ]
        )
    }
}

let hostingView = NSHostingController(
    rootView: QAForm()
        .frame(width: 600, height: 800)
)

PlaygroundPage.current.needsIndefiniteExecution = true
PlaygroundPage.current.liveView = hostingView


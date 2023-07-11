import AppKit
import LangChain
import PlaygroundSupport
import SwiftUI

struct ScrapperForm: View {
    @State var webDocuments: [Document] = []
    @State var isProcessing: Bool = false
    @State var url: String = "https://developer.apple.com/documentation/swift/applying-macros"

    var body: some View {
        Form {
            Section(header: Text("Input")) {
                TextField("URL", text: $url)
                Button("Scrap") {
                    Task {
                        do {
                            try await scrap()
                        } catch {
                            webDocuments =
                                [.init(pageContent: error.localizedDescription, metadata: [:])]
                        }
                    }
                }
                .disabled(isProcessing)
            }
            Section(header: Text("Web Content")) {
                ForEach(webDocuments, id: \.pageContent) { document in
                    VStack(alignment: .leading) {
                        Text(document.pageContent)
                            .font(.body)
                    }
                    Divider()
                }
            }
        }
        .formStyle(.grouped)
    }

    func scrap() async throws {
        webDocuments = []
        isProcessing = true
        defer { isProcessing = false }
        guard let url = URL(string: url) else { return }
        let webLoader = WebLoader(urls: [url])
        webDocuments = try await webLoader.load()
    }
}

let hostingView = NSHostingController(
    rootView: ScrapperForm()
        .frame(width: 600, height: 800)
)

PlaygroundPage.current.needsIndefiniteExecution = true
PlaygroundPage.current.liveView = hostingView


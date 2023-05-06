import Foundation
import JSONRPC
import LanguageServerProtocol
import SuggestionModel

protocol CodeiumRequestType {
    associatedtype Response: Codable
    func makeURLRequest(server: String) -> URLRequest
}

struct CodeiumResponseError: Codable, Error, LocalizedError {
    var code: String
    var message: String
    var errorDescription: String? { message }
}

enum CodeiumRequest {
    struct GetCompletion: CodeiumRequestType {
        struct Response: Codable {
            var state: State
            var completionItems: [CodeiumCompletionItem]?
        }

        struct Request: Codable {
            var metadata: Metadata
            var document: CodeiumDocument
            var editor_options: CodeiumEditorOptions
            var other_documents: [CodeiumDocument]
        }

        var requestBody: Request

        func makeURLRequest(server: String) -> URLRequest {
            var request = URLRequest(url: .init(string: "\(server)/exa.language_server_pb.LanguageServerService/GetCompletions")!)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let data = (try? JSONEncoder().encode(requestBody)) ?? Data() //
            
            request.httpMethod = "POST"
            request.httpBody = data
            
            return request
        }

    }
}


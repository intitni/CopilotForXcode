import Foundation
import JSONRPC
import LanguageServerProtocol
import SuggestionModel

protocol CodeiumRequestType {
    associatedtype Response: Codable
    func makeURLRequest(server: String) -> URLRequest
}

extension CodeiumRequestType {
    func assembleURLRequest(server: String, method: String, body: Data?) -> URLRequest {
        var request = URLRequest(url: .init(
            string: "\(server)/exa.language_server_pb.LanguageServerService/\(method)"
        )!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = body
        return request
    }
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

        struct RequestBody: Codable {
            var metadata: Metadata
            var document: CodeiumDocument
            var editor_options: CodeiumEditorOptions
            var other_documents: [CodeiumDocument]
        }

        var requestBody: RequestBody

        func makeURLRequest(server: String) -> URLRequest {
            let data = (try? JSONEncoder().encode(requestBody)) ?? Data()
            return assembleURLRequest(server: server, method: "GetCompletions", body: data)
        }
    }
    
    struct CancelRequest: CodeiumRequestType {
        struct Response: Codable {}

        struct RequestBody: Codable {
            var request_id: UInt64
            var session_id: String
        }

        var requestBody: RequestBody

        func makeURLRequest(server: String) -> URLRequest {
            let data = (try? JSONEncoder().encode(requestBody)) ?? Data()
            return assembleURLRequest(server: server, method: "CancelRequest", body: data)
        }
    }
    
    struct AcceptCompletion: CodeiumRequestType {
        struct Response: Codable {}

        struct RequestBody: Codable {
            var metadata: Metadata
            var completion_id: String
        }

        var requestBody: RequestBody

        func makeURLRequest(server: String) -> URLRequest {
            let data = (try? JSONEncoder().encode(requestBody)) ?? Data()
            return assembleURLRequest(server: server, method: "AcceptCompletion", body: data)
        }
    }
    
    struct Heartbeat: CodeiumRequestType {
        struct Response: Codable {}

        struct RequestBody: Codable {
            var metadata: Metadata
        }

        var requestBody: RequestBody

        func makeURLRequest(server: String) -> URLRequest {
            let data = (try? JSONEncoder().encode(requestBody)) ?? Data()
            return assembleURLRequest(server: server, method: "Heartbeat", body: data)
        }
    }
}


import Foundation
import JSONRPC
import LanguageServerProtocol
import SuggestionBasic

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
    struct GetProcesses: CodeiumRequestType {
        struct Response: Codable {
            var lspPort: UInt32
            var chatWebServerPort: UInt32
            var chatClientPort: UInt32
        }

        struct RequestBody: Codable {}

        var requestBody: RequestBody

        func makeURLRequest(server: String) -> URLRequest {
            let data = (try? JSONEncoder().encode(requestBody)) ?? Data()
            return assembleURLRequest(server: server, method: "GetProcesses", body: data)
        }
    }

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

    struct RemoveTrackedWorkspace: CodeiumRequestType {
        struct Response: Codable {}

        struct RequestBody: Codable {
            var workspace: String
        }

        var requestBody: RequestBody

        func makeURLRequest(server: String) -> URLRequest {
            let data = (try? JSONEncoder().encode(requestBody)) ?? Data()
            return assembleURLRequest(
                server: server,
                method: "RemoveTrackedWorkspace",
                body: data
            )
        }
    }

    struct AddTrackedWorkspace: CodeiumRequestType {
        struct Response: Codable {}

        struct RequestBody: Codable {
            var workspace: String
        }

        var requestBody: RequestBody

        func makeURLRequest(server: String) -> URLRequest {
            let data = (try? JSONEncoder().encode(requestBody)) ?? Data()
            return assembleURLRequest(
                server: server,
                method: "AddTrackedWorkspace",
                body: data
            )
        }
    }

    struct RefreshContextForIdeAction: CodeiumRequestType {
        struct Response: Codable {}

        struct RequestBody: Codable {
            var active_document: CodeiumDocument
            var open_document_filepaths: [String]
            var workspace_paths: [String]
            var blocking: Bool = false
        }

        var requestBody: RequestBody

        func makeURLRequest(server: String) -> URLRequest {
            let data = (try? JSONEncoder().encode(requestBody)) ?? Data()
            return assembleURLRequest(
                server: server,
                method: "RefreshContextForIdeAction",
                body: data
            )
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


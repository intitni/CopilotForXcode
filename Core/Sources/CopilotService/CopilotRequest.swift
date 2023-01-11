import CopilotModel
import Foundation
import JSONRPC
import LanguageServerProtocol

struct CopilotDoc: Codable {
    var source: String
    var tabSize: Int
    var indentSize: Int
    var insertSpaces: Bool
    var path: String
    var uri: String
    var relativePath: String
    var languageId: LanguageIdentifier
    var position: Position
}

protocol CopilotRequestType {
    associatedtype Response: Codable
    var request: ClientRequest { get }
}

enum CopilotRequest {
    struct SetEditorInfo: CopilotRequestType {
        struct Response: Codable {}

        var request: ClientRequest {
            .custom("setEditorInfo", .hash([
                "editorInfo": .hash([
                    "name": "Xcode",
                    "version": "",
                ]),
                "editorPluginInfo": .hash([
                    "name": "Copilot for Xcode",
                    "version": "",
                ]),
            ]))
        }
    }

    struct GetVersion: CopilotRequestType {
        struct Response: Codable {
            var version: String
        }

        var request: ClientRequest {
            .custom("getVersion", .hash([:]))
        }
    }

    struct CheckStatus: CopilotRequestType {
        struct Response: Codable {
            var status: CopilotStatus
        }

        var request: ClientRequest {
            .custom("checkStatus", .hash([:]))
        }
    }

    struct SignInInitiate: CopilotRequestType {
        struct Response: Codable {
            var verificationUri: String
            var status: String
            var userCode: String
            var expiresIn: Int
            var interval: Int
        }

        var request: ClientRequest {
            .custom("signInInitiate", .hash([:]))
        }
    }

    struct SignInConfirm: CopilotRequestType {
        struct Response: Codable {
            var status: CopilotStatus
            var user: String
        }

        var userCode: String

        var request: ClientRequest {
            .custom("signInConfirm", .hash([
                "userCode": .string(userCode),
            ]))
        }
    }

    struct SignOut: CopilotRequestType {
        struct Response: Codable {
            var status: CopilotStatus
        }

        var request: ClientRequest {
            .custom("signOut", .hash([:]))
        }
    }

    struct GetCompletions: CopilotRequestType {
        struct Response: Codable {
            var completions: [CopilotCompletion]
        }

        var doc: CopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getCompletions", .hash([
                "doc": dict,
            ]))
        }
    }

    struct GetCompletionsCycling: CopilotRequestType {
        struct Response: Codable {
            var completions: [CopilotCompletion]
        }

        var doc: CopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getCompletionsCycling", .hash([
                "doc": dict,
            ]))
        }
    }

    struct GetPanelCompletions: CopilotRequestType {
        struct Response: Codable {
            var completions: [CopilotCompletion]
        }

        var doc: CopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getPanelCompletions", .hash([
                "doc": dict,
            ]))
        }
    }

    struct NotifyAccepted: CopilotRequestType {
        struct Response: Codable {}

        var completionUUID: String

        var request: ClientRequest {
            .custom("notifyAccepted", .hash([
                "uuid": .string(completionUUID),
            ]))
        }
    }

    struct NotifyRejected: CopilotRequestType {
        struct Response: Codable {}

        var completionUUIDs: [String]

        var request: ClientRequest {
            .custom("notifyRejected", .hash([
                "uuids": .array(completionUUIDs.map(JSONValue.string)),
            ]))
        }
    }
}

import Foundation
import JSONRPC
import LanguageServerProtocol
import SuggestionModel

struct GitHubCopilotDoc: Codable {
    var source: String
    var tabSize: Int
    var indentSize: Int
    var insertSpaces: Bool
    var path: String
    var uri: String
    var relativePath: String
    var languageId: CodeLanguage
    var position: Position
    /// Buffer version. Not sure what this is for, not sure how to get it
    var version: Int = 0
}

protocol GitHubCopilotRequestType {
    associatedtype Response: Codable
    var request: ClientRequest { get }
}

public struct GitHubCopilotCodeSuggestion: Codable, Equatable {
    public init(
        text: String,
        position: CursorPosition,
        uuid: String,
        range: CursorRange,
        displayText: String
    ) {
        self.text = text
        self.position = position
        self.uuid = uuid
        self.range = range
        self.displayText = displayText
    }

    /// The new code to be inserted and the original code on the first line.
    public var text: String
    /// The position of the cursor before generating the completion.
    public var position: CursorPosition
    /// An id.
    public var uuid: String
    /// The range of the original code that should be replaced.
    public var range: CursorRange
    /// The new code to be inserted.
    public var displayText: String
}


enum GitHubCopilotRequest {
    struct SetEditorInfo: GitHubCopilotRequestType {
        struct Response: Codable {}

        var networkProxy: JSONValue? {
            let host = UserDefaults.shared.value(for: \.gitHubCopilotProxyHost)
            if host.isEmpty { return nil }
            var port = UserDefaults.shared.value(for: \.gitHubCopilotProxyPort)
            if port.isEmpty { port = "80" }
            let username = UserDefaults.shared.value(for: \.gitHubCopilotProxyUsername)
            if username.isEmpty {
                return .hash([
                    "host": .string(host),
                    "port": .number(Double(Int(port) ?? 80)),
                    "rejectUnauthorized": .bool(UserDefaults.shared
                        .value(for: \.gitHubCopilotUseStrictSSL)),
                ])
            } else {
                return .hash([
                    "host": .string(host),
                    "port": .number(Double(Int(port) ?? 80)),
                    "rejectUnauthorized": .bool(UserDefaults.shared
                        .value(for: \.gitHubCopilotUseStrictSSL)),
                    "username": .string(username),
                    "password": .string(UserDefaults.shared
                        .value(for: \.gitHubCopilotProxyPassword)),

                ])
            }
        }

        var request: ClientRequest {
            if let networkProxy {
                return .custom("setEditorInfo", .hash([
                    "editorInfo": .hash([
                        "name": "Xcode",
                        "version": "",
                    ]),
                    "editorPluginInfo": .hash([
                        "name": "Copilot for Xcode",
                        "version": "",
                    ]),
                    "networkProxy": networkProxy,
                ]))
            }

            return .custom("setEditorInfo", .hash([
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

    struct GetVersion: GitHubCopilotRequestType {
        struct Response: Codable {
            var version: String
        }

        var request: ClientRequest {
            .custom("getVersion", .hash([:]))
        }
    }

    struct CheckStatus: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
        }

        var request: ClientRequest {
            .custom("checkStatus", .hash([:]))
        }
    }

    struct SignInInitiate: GitHubCopilotRequestType {
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

    struct SignInConfirm: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
            var user: String
        }

        var userCode: String

        var request: ClientRequest {
            .custom("signInConfirm", .hash([
                "userCode": .string(userCode),
            ]))
        }
    }

    struct SignOut: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
        }

        var request: ClientRequest {
            .custom("signOut", .hash([:]))
        }
    }

    struct GetCompletions: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getCompletions", .hash([
                "doc": dict,
            ]))
        }
    }

    struct GetCompletionsCycling: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [CodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getCompletionsCycling", .hash([
                "doc": dict,
            ]))
        }
    }

    struct GetPanelCompletions: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getPanelCompletions", .hash([
                "doc": dict,
            ]))
        }
    }

    struct NotifyAccepted: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUID: String

        var request: ClientRequest {
            .custom("notifyAccepted", .hash([
                "uuid": .string(completionUUID),
            ]))
        }
    }

    struct NotifyRejected: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUIDs: [String]

        var request: ClientRequest {
            .custom("notifyRejected", .hash([
                "uuids": .array(completionUUIDs.map(JSONValue.string)),
            ]))
        }
    }
}


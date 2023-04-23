import Client
import Foundation
import Preferences
import XcodeKit

class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    var builtin: [[XCSourceEditorCommandDefinitionKey: Any]] {
        [
            GetSuggestionsCommand(),
            AcceptSuggestionCommand(),
            RejectSuggestionCommand(),
            NextSuggestionCommand(),
            PreviousSuggestionCommand(),
            ToggleRealtimeSuggestionsCommand(),
            RealtimeSuggestionsCommand(),
            PrefetchSuggestionsCommand(),
            ChatWithSelectionCommand(),
            PromptToCodeCommand(),

            SeparatorCommand().named("------"),
        ].map(makeCommandDefinition)
    }

    var custom: [[XCSourceEditorCommandDefinitionKey: Any]] {
        customCommands()
    }

    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        return builtin + custom
    }

    func extensionDidFinishLaunching() {
        #if DEBUG
        // In a debug build, we usually want to use the XPC service run from Xcode.
        #else
        // When the source extension is initialized
        // we can call a random command to wake up the XPC service.
        Task.detached {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let service = try getService()
            _ = try await service.checkStatus()
            await service.boostQoS()
        }
        #endif
    }
}

let identifierPrefix: String = Bundle.main.bundleIdentifier ?? ""

var customCommandMap = [String: String]()

protocol CommandType: AnyObject {
    var commandClassName: String { get }
    var identifier: String { get }
    var name: String { get }
}

extension CommandType where Self: NSObject {
    var commandClassName: String { Self.className() }
    var identifier: String { commandClassName }
}

extension CommandType {
    func makeCommandDefinition() -> [XCSourceEditorCommandDefinitionKey: Any] {
        [.classNameKey: commandClassName,
         .identifierKey: identifierPrefix + identifier,
         .nameKey: name]
    }
}

func makeCommandDefinition(_ commandType: CommandType)
    -> [XCSourceEditorCommandDefinitionKey: Any]
{
    commandType.makeCommandDefinition()
}

func customCommands() -> [[XCSourceEditorCommandDefinitionKey: Any]] {
    let definitions = UserDefaults.shared.value(for: \.customCommands).map {
        [
            XCSourceEditorCommandDefinitionKey.classNameKey: CustomCommand.className(),
            XCSourceEditorCommandDefinitionKey
                .identifierKey: identifierPrefix + "CustomCommand\($0.name.sha1HexString)",
            .nameKey: $0.name,
        ]
    }

    for item in definitions {
        let name = item[.nameKey]
        let identifier = item[.identifierKey]
        if let identifier {
            customCommandMap[identifier] = name
        }
    }

    return definitions
}

import CryptoKit

// CryptoKit.Digest utils
extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }

    var hexStr: String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}

extension String {
    var sha1HexString: String {
        Insecure.SHA1.hash(data: data(using: .utf8) ?? Data()).hexStr
    }
}

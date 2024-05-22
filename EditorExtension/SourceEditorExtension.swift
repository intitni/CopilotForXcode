import Client
import Foundation
import Preferences
import XcodeKit

#if canImport(PreferencesPlus)
import PreferencesPlus
#endif

class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    var builtin: [[XCSourceEditorCommandDefinitionKey: Any]] {
        [
            GetSuggestionsCommand(),
            AcceptSuggestionCommand(),
            RejectSuggestionCommand(),
            NextSuggestionCommand(),
            PreviousSuggestionCommand(),
            PromptToCodeCommand(),
            AcceptPromptToCodeCommand(),
            OpenChatCommand(),
            ToggleRealtimeSuggestionsCommand(),
        ].map(makeCommandDefinition)
    }
    
    var optional: [[XCSourceEditorCommandDefinitionKey: Any]] {
        var all = [[XCSourceEditorCommandDefinitionKey: Any]]()
        
        #if canImport(PreferencesPlus)
        if UserDefaults.shared.value(for: \.enableCloseIdleTabCommandInXcodeMenu) {
            all.append(CloseIdleTabsCommand().makeCommandDefinition())
        }
        #endif
        
        return all
    }
    
    var internalUse: [[XCSourceEditorCommandDefinitionKey: Any]] {
        [
            SeparatorCommand().named("------"),
            RealtimeSuggestionsCommand(),
            PrefetchSuggestionsCommand(),
        ].map(makeCommandDefinition)
    }

    var custom: [[XCSourceEditorCommandDefinitionKey: Any]] {
        let all = customCommands()
        if all.isEmpty {
            return []
        }
        return [SeparatorCommand().named("------")].map(makeCommandDefinition) + all
    }

    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        return builtin + optional + custom + internalUse
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
            _ = try await service.getXPCServiceVersion()
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
    var definitions = [[XCSourceEditorCommandDefinitionKey: String]]()
    for command in UserDefaults.shared.value(for: \.customCommands) {
        let identifier = identifierPrefix + "CustomCommand\(command.id)"
        definitions.append([
            .classNameKey: CustomCommand.className(),
            .identifierKey: identifier,
            .nameKey: command.name,
        ])
        
        customCommandMap[identifier] = command.id
    }
    
    return definitions
}

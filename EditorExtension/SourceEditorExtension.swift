import Foundation
import XcodeKit

class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        return [
            GetSuggestionsCommand(),
            AcceptSuggestionCommand(),
            RejectSuggestionCommand(),
            NextSuggestionCommand(),
            PreviousSuggestionCommand(),
            TurnOnRealtimeSuggestionsCommand(),
            TurnOffRealtimeSuggestionsCommand(),
            RealtimeSuggestionsCommand(),
        ].map(makeCommandDefinition)
    }
}

private let identifierPrefix: String = Bundle.main.bundleIdentifier ?? ""

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
        return [.classNameKey: commandClassName,
                .identifierKey: identifierPrefix + identifier,
                .nameKey: name]
    }
}

func makeCommandDefinition(_ commandType: CommandType) -> [XCSourceEditorCommandDefinitionKey: Any] {
    return commandType.makeCommandDefinition()
}

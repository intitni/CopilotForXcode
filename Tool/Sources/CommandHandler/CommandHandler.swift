import Dependencies
import Foundation
import Preferences
import SuggestionBasic
import Toast
import XcodeInspector

/// Provides an interface to handle commands.
public protocol CommandHandler {
    // MARK: Suggestion

    func presentSuggestions(_ suggestions: [CodeSuggestion]) async
    func presentPreviousSuggestion() async
    func presentNextSuggestion() async
    func rejectSuggestions() async
    func acceptSuggestion() async
    func dismissSuggestion() async
    func generateRealtimeSuggestions(sourceEditor: SourceEditor?) async

    // MARK: Chat

    func openChat(forceDetach: Bool)
    func sendChatMessage(_ message: String) async

    // MARK: Prompt to Code

    func acceptPromptToCode() async

    // MARK: Custom Command

    func handleCustomCommand(_ command: CustomCommand) async

    // MARK: Toast

    func toast(_ string: String, as type: ToastType)
}

public struct CommandHandlerDependencyKey: DependencyKey {
    public static var liveValue: CommandHandler = NoopCommandHandler()
}

public extension DependencyValues {
    var commandHandler: CommandHandler {
        get { self[CommandHandlerDependencyKey.self] }
        set { self[CommandHandlerDependencyKey.self] = newValue }
    }
}

struct NoopCommandHandler: CommandHandler {
    static let shared: CommandHandler = NoopCommandHandler()

    func presentSuggestions(_: [CodeSuggestion]) async {}
    func presentPreviousSuggestion() async {}
    func presentNextSuggestion() async {}
    func rejectSuggestions() async {}
    func acceptSuggestion() async {}
    func dismissSuggestion() async {}
    func generateRealtimeSuggestions(sourceEditor: SourceEditor?) async {}
    func openChat(forceDetach: Bool) {}
    func sendChatMessage(_: String) async {}
    func acceptPromptToCode() async {}
    func handleCustomCommand(_: CustomCommand) async {}
    func toast(_: String, as: ToastType) {}
}


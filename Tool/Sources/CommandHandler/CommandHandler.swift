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

    func openChat(forceDetach: Bool, activateThisApp: Bool)
    func sendChatMessage(_ message: String) async

    // MARK: Prompt to Code

    func acceptPromptToCode() async

    // MARK: Custom Command

    func handleCustomCommand(_ command: CustomCommand) async

    // MARK: Toast

    func toast(_ string: String, as type: ToastType)
}

public struct CommandHandlerDependencyKey: DependencyKey {
    public static var liveValue: CommandHandler = UniversalCommandHandler.shared
    public static var testValue: CommandHandler = NoopCommandHandler()
}

public extension DependencyValues {
    /// In production, you need to override the command handler globally by setting
    /// ``UniversalCommandHandler.shared.commandHandler``.
    ///
    /// In tests, you can use ``withDependency`` to mock it.
    var commandHandler: CommandHandler {
        get { self[CommandHandlerDependencyKey.self] }
        set { self[CommandHandlerDependencyKey.self] = newValue }
    }
}

public final class UniversalCommandHandler: CommandHandler {
    public static let shared: UniversalCommandHandler = UniversalCommandHandler()
    
    public var commandHandler: CommandHandler = NoopCommandHandler()
    
    private init() {}

    public func presentSuggestions(_ suggestions: [SuggestionBasic.CodeSuggestion]) async {
        await commandHandler.presentSuggestions(suggestions)
    }

    public func presentPreviousSuggestion() async {
        await commandHandler.presentPreviousSuggestion()
    }

    public func presentNextSuggestion() async {
        await commandHandler.presentNextSuggestion()
    }

    public func rejectSuggestions() async {
        await commandHandler.rejectSuggestions()
    }

    public func acceptSuggestion() async {
        await commandHandler.acceptSuggestion()
    }

    public func dismissSuggestion() async {
        await commandHandler.dismissSuggestion()
    }

    public func generateRealtimeSuggestions(sourceEditor: SourceEditor?) async {
        await commandHandler.generateRealtimeSuggestions(sourceEditor: sourceEditor)
    }

    public func openChat(forceDetach: Bool, activateThisApp: Bool) {
        commandHandler.openChat(forceDetach: forceDetach, activateThisApp: activateThisApp)
    }

    public func sendChatMessage(_ message: String) async {
        await commandHandler.sendChatMessage(message)
    }

    public func acceptPromptToCode() async {
        await commandHandler.acceptPromptToCode()
    }

    public func handleCustomCommand(_ command: CustomCommand) async {
        await commandHandler.handleCustomCommand(command)
    }

    public func toast(_ string: String, as type: ToastType) {
        commandHandler.toast(string, as: type)
    }
}

struct NoopCommandHandler: CommandHandler {
    func presentSuggestions(_: [CodeSuggestion]) async {}
    func presentPreviousSuggestion() async {}
    func presentNextSuggestion() async {}
    func rejectSuggestions() async {}
    func acceptSuggestion() async {}
    func dismissSuggestion() async {}
    func generateRealtimeSuggestions(sourceEditor: SourceEditor?) async {}
    func openChat(forceDetach: Bool, activateThisApp: Bool) {}
    func sendChatMessage(_: String) async {}
    func acceptPromptToCode() async {}
    func handleCustomCommand(_: CustomCommand) async {}
    func toast(_: String, as: ToastType) {}
}


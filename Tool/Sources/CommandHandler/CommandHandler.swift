import ComposableArchitecture
import Dependencies
import Foundation
import ModificationBasic
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
    func acceptActiveSuggestionLineInGroup(atIndex index: Int?) async
    func dismissSuggestion() async
    func generateRealtimeSuggestions(sourceEditor: SourceEditor?) async

    // MARK: Chat

    func openChat(forceDetach: Bool, activateThisApp: Bool)
    func sendChatMessage(_ message: String) async

    // MARK: Modification

    func acceptModification() async
    func presentModification(state: Shared<ModificationState>) async

    // MARK: Custom Command

    func handleCustomCommand(_ command: CustomCommand) async

    // MARK: Toast

    func toast(_ string: String, as type: ToastType)

    // MARK: Others

    func presentFile(at fileURL: URL, line: Int?) async

    func presentFile(at fileURL: URL) async
}

public extension CommandHandler {
    /// Default implementation for `presentFile(at:line:)`.
    func presentFile(at fileURL: URL) async {
        await presentFile(at: fileURL, line: nil)
    }
}

public struct CommandHandlerDependencyKey: DependencyKey {
    public static var liveValue: CommandHandler = UniversalCommandHandler.shared
    public static var testValue: CommandHandler = NOOPCommandHandler()
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
    public static let shared: UniversalCommandHandler = .init()

    public var commandHandler: CommandHandler = NOOPCommandHandler()

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
    
    public func acceptActiveSuggestionLineInGroup(atIndex index: Int?) async {
        await commandHandler.acceptActiveSuggestionLineInGroup(atIndex: index)
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

    public func acceptModification() async {
        await commandHandler.acceptModification()
    }

    public func presentModification(state: Shared<ModificationState>) async {
        await commandHandler.presentModification(state: state)
    }

    public func handleCustomCommand(_ command: CustomCommand) async {
        await commandHandler.handleCustomCommand(command)
    }

    public func toast(_ string: String, as type: ToastType) {
        commandHandler.toast(string, as: type)
    }

    public func presentFile(at fileURL: URL, line: Int?) async {
        await commandHandler.presentFile(at: fileURL, line: line)
    }
}

struct NOOPCommandHandler: CommandHandler {
    func presentSuggestions(_ suggestions: [CodeSuggestion]) async {
        print("present \(suggestions.count) suggestions")
    }

    func presentPreviousSuggestion() async {
        print("previous suggestion")
    }

    func presentNextSuggestion() async {
        print("next suggestion")
    }

    func rejectSuggestions() async {
        print("reject suggestions")
    }

    func acceptSuggestion() async {
        print("accept suggestion")
    }
    
    func acceptActiveSuggestionLineInGroup(atIndex index: Int?) async {
        print("accept active suggestion line in group at index \(String(describing: index))")
    }

    func dismissSuggestion() async {
        print("dismiss suggestion")
    }

    func generateRealtimeSuggestions(sourceEditor: SourceEditor?) async {
        print("generate realtime suggestions")
    }

    func openChat(forceDetach: Bool, activateThisApp: Bool) {
        print("open chat")
    }

    func sendChatMessage(_: String) async {
        print("send chat message")
    }

    func acceptModification() async {
        print("accept prompt to code")
    }

    func presentModification(state: Shared<ModificationState>) {
        print("present modification")
    }

    func handleCustomCommand(_: CustomCommand) async {
        print("handle custom command")
    }

    func toast(_: String, as: ToastType) {
        print("toast")
    }

    func presentFile(at fileURL: URL, line: Int?) async {
        print("present file")
    }
}


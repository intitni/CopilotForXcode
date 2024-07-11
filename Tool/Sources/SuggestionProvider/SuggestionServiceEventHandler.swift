import CopilotForXcodeKit
import Foundation
import SuggestionBasic

public protocol SuggestionServiceEventHandler {
    func didAccept(_ suggestion: SuggestionBasic.CodeSuggestion, workspaceInfo: WorkspaceInfo)
    func didReject(_ suggestions: [SuggestionBasic.CodeSuggestion], workspaceInfo: WorkspaceInfo)
}

public enum SuggestionServiceEventHandlerContainer {
    static var builtinHandlers: [SuggestionServiceEventHandler] = []

    static var customHandlers: [SuggestionServiceEventHandler] = []

    public static var handlers: [SuggestionServiceEventHandler] {
        builtinHandlers + customHandlers
    }

    public static func addHandler(_ handler: SuggestionServiceEventHandler) {
        customHandlers.append(handler)
    }

    public static func addHandlers(_ handlers: [SuggestionServiceEventHandler]) {
        customHandlers.append(contentsOf: handlers)
    }
}


import Foundation
import SuggestionBasic
import CopilotForXcodeKit

public protocol SuggestionServiceEventHandler {
    func didAccept(_ suggestion: CodeSuggestion, workspaceInfo: WorkspaceInfo)
    func didReject(_ suggestion: CodeSuggestion, workspaceInfo: WorkspaceInfo)
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
}

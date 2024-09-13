import ActiveApplicationMonitor
import AppActivator
import AppKit
import ChatService
import ComposableArchitecture
import Foundation
import GitHubCopilotService
import OpenAIService
import PromptToCodeService
import SuggestionBasic
import SuggestionWidget

@MainActor
final class WidgetDataSource {}

extension WidgetDataSource: SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> PresentingCodeSuggestion? {
        for workspace in Service.shared.workspacePool.workspaces.values {
            if let filespace = workspace.filespaces[url],
               let suggestion = filespace.presentingSuggestion
            {
                return .init(
                    code: suggestion.text,
                    language: filespace.language.rawValue,
                    startLineIndex: suggestion.position.line,
                    suggestionCount: filespace.suggestions.count,
                    currentSuggestionIndex: filespace.suggestionIndex,
                    replacingRange: suggestion.range,
                    replacingLines: suggestion.replacingLines,
                    descriptions: suggestion.descriptions
                )
            }
        }
        return nil
    }
}


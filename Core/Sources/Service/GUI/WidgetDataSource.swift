import ActiveApplicationMonitor
import ChatService
import ComposableArchitecture
import Foundation
import GitHubCopilotService
import OpenAIService
import PromptToCodeService
import SuggestionModel
import SuggestionWidget

@MainActor
final class WidgetDataSource {}

extension WidgetDataSource: SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> SuggestionProvider? {
        for workspace in Service.shared.workspacePool.workspaces.values {
            if let filespace = workspace.filespaces[url],
               let suggestion = filespace.presentingSuggestion
            {
                return .init(
                    code: suggestion.text,
                    language: filespace.language,
                    startLineIndex: suggestion.position.line,
                    suggestionCount: filespace.suggestions.count,
                    currentSuggestionIndex: filespace.suggestionIndex,
                    onSelectPreviousSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.presentPreviousSuggestion()
                        }
                    },
                    onSelectNextSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.presentNextSuggestion()
                        }
                    },
                    onRejectSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.rejectSuggestions()
                            if let app = ActiveApplicationMonitor.shared.previousApp,
                               app.isXcode
                            {
                                try await Task.sleep(nanoseconds: 200_000_000)
                                app.activate()
                            }
                        }
                    },
                    onAcceptSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.acceptSuggestion()
                            if let app = ActiveApplicationMonitor.shared.previousApp,
                               app.isXcode
                            {
                                try await Task.sleep(nanoseconds: 200_000_000)
                                app.activate()
                            }
                        }
                    }
                )
            }
        }
        return nil
    }
}


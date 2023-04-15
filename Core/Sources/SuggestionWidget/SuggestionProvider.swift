import Foundation
import SwiftUI

public final class SuggestionProvider: ObservableObject {
    @Published public var code: String = ""
    @Published public var language: String = ""
    @Published public var startLineIndex: Int = 0
    @Published public var suggestionCount: Int = 0
    @Published public var currentSuggestionIndex: Int = 0
    @Published public var commonPrecedingSpaceCount = 0

    public var onSelectPreviousSuggestionTapped: () -> Void
    public var onSelectNextSuggestionTapped: () -> Void
    public var onRejectSuggestionTapped: () -> Void
    public var onAcceptSuggestionTapped: () -> Void

    public init(
        code: String = "",
        language: String = "",
        startLineIndex: Int = 0,
        suggestionCount: Int = 0,
        currentSuggestionIndex: Int = 0,
        onSelectPreviousSuggestionTapped: @escaping () -> Void = {},
        onSelectNextSuggestionTapped: @escaping () -> Void = {},
        onRejectSuggestionTapped: @escaping () -> Void = {},
        onAcceptSuggestionTapped: @escaping () -> Void = {}
    ) {
        self.code = code
        self.language = language
        self.startLineIndex = startLineIndex
        self.suggestionCount = suggestionCount
        self.currentSuggestionIndex = currentSuggestionIndex
        self.onSelectPreviousSuggestionTapped = onSelectPreviousSuggestionTapped
        self.onSelectNextSuggestionTapped = onSelectNextSuggestionTapped
        self.onRejectSuggestionTapped = onRejectSuggestionTapped
        self.onAcceptSuggestionTapped = onAcceptSuggestionTapped
    }

    func selectPreviousSuggestion() { onSelectPreviousSuggestionTapped() }
    func selectNextSuggestion() { onSelectNextSuggestionTapped() }
    func rejectSuggestion() { onRejectSuggestionTapped() }
    func acceptSuggestion() { onAcceptSuggestionTapped() }
}

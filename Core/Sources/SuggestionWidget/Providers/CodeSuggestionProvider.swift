import Combine
import Foundation
import Perception
import SharedUIComponents
import SwiftUI
import XcodeInspector

@Perceptible
public final class CodeSuggestionProvider: Equatable {
    public static func == (lhs: CodeSuggestionProvider, rhs: CodeSuggestionProvider) -> Bool {
        lhs.code == rhs.code && lhs.language == rhs.language
    }

    public var code: String = ""
    public var language: String = ""
    public var startLineIndex: Int = 0
    public var suggestionCount: Int = 0
    public var currentSuggestionIndex: Int = 0
    public var extraInformation: String = ""

    @PerceptionIgnored public var onSelectPreviousSuggestionTapped: () -> Void
    @PerceptionIgnored public var onSelectNextSuggestionTapped: () -> Void
    @PerceptionIgnored public var onRejectSuggestionTapped: () -> Void
    @PerceptionIgnored public var onAcceptSuggestionTapped: () -> Void
    @PerceptionIgnored public var onDismissSuggestionTapped: () -> Void

    public init(
        code: String = "",
        language: String = "",
        startLineIndex: Int = 0,
        startCharacerIndex: Int = 0,
        suggestionCount: Int = 0,
        currentSuggestionIndex: Int = 0,
        onSelectPreviousSuggestionTapped: @escaping () -> Void = {},
        onSelectNextSuggestionTapped: @escaping () -> Void = {},
        onRejectSuggestionTapped: @escaping () -> Void = {},
        onAcceptSuggestionTapped: @escaping () -> Void = {},
        onDismissSuggestionTapped: @escaping () -> Void = {}
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
        self.onDismissSuggestionTapped = onDismissSuggestionTapped
    }

    func selectPreviousSuggestion() { onSelectPreviousSuggestionTapped() }
    func selectNextSuggestion() { onSelectNextSuggestionTapped() }
    func rejectSuggestion() { onRejectSuggestionTapped() }
    func acceptSuggestion() { onAcceptSuggestionTapped() }
    func dismissSuggestion() { onDismissSuggestionTapped() }

    
}


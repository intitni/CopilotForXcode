import Foundation
import SwiftUI

public final class SuggestionProvider: ObservableObject {
    @Published public var code: String = "" {
        didSet { highlightedCode = nil }
    }
    @Published public var language: String = "" {
        didSet { highlightedCode = nil }
    }
    @Published public var startLineIndex: Int = 0
    @Published public var suggestionCount: Int = 0
    @Published public var currentSuggestionIndex: Int = 0
    @Published public var commonPrecedingSpaceCount = 0
    
    private var colorScheme: ColorScheme = .light
    private var highlightedCode: [NSAttributedString]? = nil
    
    func highlightedCode(colorScheme: ColorScheme) -> [NSAttributedString] {
        if colorScheme != self.colorScheme { highlightedCode = nil }
        self.colorScheme = colorScheme
        if let highlightedCode { return highlightedCode }
        let (new, spaceCount) = highlighted(
            code: code,
            language: language,
            brightMode: colorScheme != .dark,
            droppingLeadingSpaces: true
        )
        highlightedCode = new
        Task { @MainActor in
            commonPrecedingSpaceCount = spaceCount
        }
        return new
    }
    
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

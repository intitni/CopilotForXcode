import Foundation
import SwiftUI

public final class PromptToCodeProvider: ObservableObject {
    let id = UUID()
    
    @Published public var code: String
    @Published public var language: String
    @Published public var description: String
    @Published public var isResponding: Bool
    @Published public var startLineIndex: Int
    @Published public var startLineColumn: Int
    @Published public var requirement: String
    @Published public var errorMessage: String
    @Published public var canRevert: Bool
    @Published public var isContinuous: Bool

    public var onRevertTapped: () -> Void
    public var onStopRespondingTap: () -> Void
    public var onCancelTapped: () -> Void
    public var onAcceptSuggestionTapped: () -> Void
    public var onRequirementSent: (String) -> Void
    public var onContinuousToggleClick: () -> Void

    public init(
        code: String = "",
        language: String = "",
        description: String = "",
        isResponding: Bool = false,
        startLineIndex: Int = 0,
        startLineColumn: Int = 0,
        requirement: String = "",
        errorMessage: String = "",
        canRevert: Bool = false,
        isContinuous: Bool = false,
        onRevertTapped: @escaping () -> Void = {},
        onStopRespondingTap: @escaping () -> Void = {},
        onCancelTapped: @escaping () -> Void = {},
        onAcceptSuggestionTapped: @escaping () -> Void = {},
        onRequirementSent: @escaping (String) -> Void = { _ in },
        onContinuousToggleClick: @escaping () -> Void = {}
    ) {
        self.code = code
        self.language = language
        self.description = description
        self.isResponding = isResponding
        self.startLineIndex = startLineIndex
        self.startLineColumn = startLineColumn
        self.requirement = requirement
        self.errorMessage = errorMessage
        self.canRevert = canRevert
        self.isContinuous = isContinuous
        self.onRevertTapped = onRevertTapped
        self.onStopRespondingTap = onStopRespondingTap
        self.onCancelTapped = onCancelTapped
        self.onAcceptSuggestionTapped = onAcceptSuggestionTapped
        self.onRequirementSent = onRequirementSent
        self.onContinuousToggleClick = onContinuousToggleClick
    }

    func revert() {
        onRevertTapped()
        errorMessage = ""
    }
    func stopResponding() {
        onStopRespondingTap()
        errorMessage = ""
    }
    func cancel() { onCancelTapped() }
    func sendRequirement() {
        guard !isResponding else { return }
        guard !requirement.isEmpty else { return }
        onRequirementSent(requirement)
        requirement = ""
        errorMessage = ""
    }

    func acceptSuggestion() { onAcceptSuggestionTapped() }
    
    func toggleContinuous() { onContinuousToggleClick() }
}

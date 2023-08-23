import Foundation
import SuggestionModel
import SwiftUI

public final class PromptToCodeProvider: ObservableObject {
    let id = UUID()
    let name: String?

    @Published public var code: String
    @Published public var language: String
    @Published public var description: String
    @Published public var isResponding: Bool
    public var startLineIndex: Int { attachedToRange?.start.line ?? 0 }
    public var startLineColumn: Int { attachedToRange?.start.character ?? 0 }
    @Published public var attachedToRange: CursorRange?
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
        attachedToRange: CursorRange? = nil,
        requirement: String = "",
        errorMessage: String = "",
        canRevert: Bool = false,
        isContinuous: Bool = false,
        name: String? = nil,
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
        self.attachedToRange = attachedToRange
        self.requirement = requirement
        self.errorMessage = errorMessage
        self.canRevert = canRevert
        self.isContinuous = isContinuous
        self.name = name
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


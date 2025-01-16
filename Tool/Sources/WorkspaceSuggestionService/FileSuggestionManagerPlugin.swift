import Foundation
import IdentifiedCollections
import Perception
import SuggestionBasic
import Workspace

public final class FileSuggestionManagerPlugin: FilespacePlugin {
    static var suggestionProviders: [ObjectIdentifier: (FileSuggestionManager)
        -> FilespaceSuggestionProvider] = [:]

    public let suggestionManager = {
        let suggestionManager = FileSuggestionManager()
        for provider in suggestionProviders.values {
            let provider = provider(suggestionManager)
            suggestionManager.suggestionProviders.append(provider)
            provider.delegate = suggestionManager
        }
        return suggestionManager
    }()

    public static func registerSuggestionProvider<Provider: FilespaceSuggestionProvider>(
        _ provider: @escaping (FileSuggestionManager) -> Provider
    ) {
        let id = ObjectIdentifier(Provider.self)
        suggestionProviders[id] = provider
    }
}

public extension Filespace {
    var suggestionManager: FileSuggestionManager? {
        plugin(for: FileSuggestionManagerPlugin.self)?.suggestionManager
    }
}

@Perceptible
public final class FileSuggestionManager {
    @PerceptionIgnored
    private(set) var cursorPosition = CursorPosition.zero

    @PerceptionIgnored
    let defaultSuggestionProvider = DefaultFilespaceSuggestionProvider()

    @PerceptionIgnored
    fileprivate(set) var suggestionProviders: [FilespaceSuggestionProvider] = []

    public private(set) var displaySuggestions: CircularSuggestionList = .init()

    public init() {
        defaultSuggestionProvider.delegate = self
    }

    public func receiveSuggestions(_ suggestions: [CodeSuggestion]) {
        Task { @WorkspaceActor in
            defaultSuggestionProvider.receiveSuggestions(suggestions)
        }
    }

    @WorkspaceActor
    public func invalidateAllSuggestions() {
        defer { renderDisplaySuggestionsAtCursor() }
        defaultSuggestionProvider.invalidateAllSuggestion()
        suggestionProviders.forEach { $0.invalidateAllSuggestion() }
    }

    @WorkspaceActor
    public func invalidateSuggestion(id: CodeSuggestion.ID) {
        defer { renderDisplaySuggestionsAtCursor() }
        defaultSuggestionProvider.invalidateSuggestion(id: id)
        suggestionProviders.forEach { $0.invalidateSuggestion(id: id) }
    }

    @WorkspaceActor
    public func invalidateDisplaySuggestions() {
        defer { renderDisplaySuggestionsAtCursor() }
        for suggestion in displaySuggestions {
            switch suggestion {
            case let .group(group):
                for item in group.suggestions {
                    invalidateSuggestion(id: item.id)
                }
            case let .action(action):
                invalidateSuggestion(id: action.id)
            }
        }
    }

    @WorkspaceActor
    public func invalidateDisplaySuggestions(inGroup groupIndex: Int) {
        guard groupIndex < displaySuggestions.count, groupIndex >= 0 else { return }
        let suggestion = displaySuggestions[groupIndex]
        defer { renderDisplaySuggestionsAtCursor() }
        switch suggestion {
        case let .group(group):
            for item in group.suggestions {
                invalidateSuggestion(id: item.id)
            }
        case let .action(action):
            invalidateSuggestion(id: action.id)
        }
    }

    @WorkspaceActor
    public func invalidateSuggestions(after position: CursorPosition) {
        defer { renderDisplaySuggestionsAtCursor() }
        defaultSuggestionProvider.invalidateSuggestions(after: position)
        suggestionProviders.forEach { $0.invalidateSuggestions(after: position) }
    }

    public func updateCursorPosition(_ position: CursorPosition) {
        cursorPosition = position
    }

    public func nextSuggestionGroup() {
        displaySuggestions.offsetAnchor(1)
    }

    public func nextSuggestionInGroup(index: Int) {
        if case var .group(group) = displaySuggestions[index] {
            group.offsetIndex(1)
            displaySuggestions[index] = .group(group)
        }
    }

    public func previousSuggestionGroup() {
        displaySuggestions.offsetAnchor(-1)
    }

    public func previousSuggestionInGroup(index: Int) {
        if case var .group(group) = displaySuggestions[index] {
            group.offsetIndex(-1)
            displaySuggestions[index] = .group(group)
        }
    }
}

extension FileSuggestionManager: FilespaceSuggestionProviderDelegate {
    func onCodeSuggestionChange() {
        renderDisplaySuggestionsAtCursor()
    }
}

public extension FileSuggestionManager {
    struct CircularSuggestionList: Sequence, Equatable {
        public static var empty: CircularSuggestionList {
            .init(suggestions: [], anchorIndex: 0)
        }

        public var suggestions: IdentifiedArrayOf<DisplaySuggestion> = []
        public var anchorIndex = 0

        public typealias Element = DisplaySuggestion
        public typealias Iterator = AnyIterator<Element>

        public func makeIterator() -> AnyIterator<Element> {
            var index = 0
            let count = suggestions.count
            var actualIndex: Int {
                Self.actualIndex(
                    of: index,
                    anchorIndex: anchorIndex,
                    count: count
                )
            }
            return AnyIterator {
                guard !self.suggestions.isEmpty, index < count else { return nil }
                let element = self.suggestions[actualIndex]
                index += 1
                return element
            }
        }

        public var underestimatedCount: Int {
            return suggestions.count
        }

        public var activeSuggestion: DisplaySuggestion? {
            guard suggestions.endIndex > anchorIndex, anchorIndex >= 0 else { return nil }
            return suggestions[anchorIndex]
        }

        public subscript(id: DisplaySuggestion.ID) -> DisplaySuggestion? {
            suggestions[id: id]
        }

        public subscript(_ index: Int) -> DisplaySuggestion {
            get {
                precondition(suggestions.endIndex > index && index >= 0)
                let offsetIndex = Self.actualIndex(
                    of: index,
                    anchorIndex: anchorIndex,
                    count: suggestions.count
                )
                return suggestions[offsetIndex]
            }
            set {
                precondition(suggestions.endIndex > index && index >= 0)
                let offsetIndex = Self.actualIndex(
                    of: index,
                    anchorIndex: anchorIndex,
                    count: suggestions.count
                )
                suggestions[offsetIndex] = newValue
            }
        }

        public mutating func offsetAnchor(_ offset: Int) {
            guard !suggestions.isEmpty else {
                anchorIndex = 0
                return
            }
            let newIndex = anchorIndex + offset
            anchorIndex = (newIndex + suggestions.count) % suggestions.count
        }

        public var indices: IdentifiedArrayOf<DisplaySuggestion>.Indices {
            return suggestions.indices
        }

        public var count: Int { suggestions.count }
        public var isEmpty: Bool { suggestions.isEmpty }

        static func actualIndex(of index: Int, anchorIndex: Int, count: Int) -> Int {
            if count <= 0 { return 0 }
            return (index + anchorIndex + count) % count
        }
    }

    enum DisplaySuggestion: Identifiable, Equatable {
        case group(DisplayGroup)
        case action(DisplayAction)

        public var id: String {
            switch self {
            case let .group(group):
                return group.id
            case let .action(action):
                return action.id
            }
        }

        var activeCodeSuggestion: CodeSuggestion? {
            switch self {
            case let .group(group):
                return group.suggestions.first
            case let .action(action):
                return action.suggestion
            }
        }
    }

    struct DisplayGroup: Identifiable, Equatable {
        public var id: String { source }
        public var source: String
        public var suggestions: [CodeSuggestion]
        public var suggestionIndex = 0
        public var activeSuggestion: CodeSuggestion? {
            guard suggestions.endIndex > suggestionIndex, suggestionIndex >= 0 else { return nil }
            return suggestions[suggestionIndex]
        }

        public mutating func offsetIndex(_ offset: Int) {
            let newIndex = suggestionIndex + offset
            suggestionIndex = (newIndex + suggestions.count) % suggestions.count
        }
    }

    struct DisplayAction: Identifiable, Equatable {
        public var id: String
        public var descriptions: [CodeSuggestion.Description] { suggestion.descriptions }
        public var suggestion: CodeSuggestion
    }
}

extension FileSuggestionManager {
    func renderDisplaySuggestionsAtCursor() {
        Task { @MainActor in
            let suggestions = await collectDisplaySuggestionsAtCursor()
            displaySuggestions.suggestions = suggestions
            if displaySuggestions.anchorIndex <= 0 {
                displaySuggestions.anchorIndex = 0
            } else if displaySuggestions.anchorIndex >= displaySuggestions.suggestions.endIndex {
                displaySuggestions.anchorIndex = displaySuggestions.suggestions.endIndex - 1
            }
        }
    }

    @WorkspaceActor
    func collectDisplaySuggestionsAtCursor() -> IdentifiedArrayOf<DisplaySuggestion> {
        let existedGroupSuggestionIndices: [String: Int] = displaySuggestions
            .reduce(into: [:]) { result, suggestion in
                if case let .group(group) = suggestion {
                    result[group.id] = group.suggestionIndex
                }
            }
        var groups = IdentifiedArrayOf<DisplayGroup>()
        var actions = IdentifiedArrayOf<DisplayAction>()
        let suggestions = suggestions(
            defaultSuggestionProvider.codeSuggestions,
            for: cursorPosition
        )
        for suggestion in suggestions {
            if isSuggestionAnAction(suggestion) {
                actions.append(.init(id: suggestion.id, suggestion: suggestion))
            } else {
                let group = suggestion[metadata: .group] ?? ""
                if groups[id: group] != nil {
                    groups[id: group]?.suggestions.append(suggestion)
                } else {
                    let newGroup = DisplayGroup(
                        source: group,
                        suggestions: [suggestion]
                    )
                    groups.append(newGroup)
                }
            }
        }

        var result = IdentifiedArrayOf<DisplaySuggestion>()
        result.append(contentsOf: groups.map {
            var group = $0
            group.suggestionIndex = existedGroupSuggestionIndices[group.id] ?? 0
            if group.suggestionIndex >= group.suggestions.count {
                group.suggestionIndex = 0
            }
            return .group(group)
        })
        result.append(contentsOf: actions.map { .action($0) })

        return result
    }

    func isSuggestionAnAction(_ suggestion: CodeSuggestion) -> Bool {
        suggestion.descriptions.contains { $0.kind == .action }
            && suggestion.text.isEmpty
            && suggestion.range.isEmpty
    }

    func suggestions(
        _ codeSuggestions: IdentifiedArrayOf<CodeSuggestion>,
        for cursorPosition: CursorPosition
    ) -> [CodeSuggestion] {
        codeSuggestions.filter {
            switch $0.effectiveRange {
            case .replacingRange:
                return $0.range.contains(cursorPosition)
            case .line:
                return $0.range.start.line == cursorPosition.line
            case .full:
                return true
            case .ignored:
                return false
            }
        }
    }
}



@Perceptible
public final class FileSuggestionManager {
    @PerceptionIgnored
    private(set) var cursorPosition = CursorPosition.zero

    @PerceptionIgnored
    let defaultSuggestionProvider = DefaultFilespaceSuggestionProvider()

    @PerceptionIgnored
    fileprivate(set) var suggestionProviders: [FilespaceSuggestionProvider] = []

    @MainActor
    public var displaySuggestions: CircularSuggestionList { _displaySuggestions }

    /// Only used in places that does't work with async await.
    public var _mainThread_displaySuggestions: CircularSuggestionList {
        if Thread.isMainThread {
            return _displaySuggestions
        } else {
            return DispatchQueue.main.sync { _displaySuggestions }
        }
    }

    private var _displaySuggestions: CircularSuggestionList = .init()

    public init() {
        defaultSuggestionProvider.delegate = self
    }

    public func receiveSuggestions(_ suggestions: [CodeSuggestion]) {
        Task { @WorkspaceActor in
            defaultSuggestionProvider.receiveSuggestions(suggestions)
        }
    }

    public func invalidateAllSuggestions() {
        defer { onCodeSuggestionChange() }
        Task {
            await defaultSuggestionProvider.invalidateAllSuggestion()
            for provider in suggestionProviders {
                await provider.invalidateAllSuggestion()
            }
        }
    }

    public func invalidateSuggestion(id: CodeSuggestion.ID) {
        defer { onCodeSuggestionChange() }
        Task {
            await defaultSuggestionProvider.invalidateSuggestion(id: id)
            for provider in suggestionProviders {
                await provider.invalidateSuggestion(id: id)
            }
        }
    }

    public func invalidateDisplaySuggestions() {
        defer { onCodeSuggestionChange() }
        Task {
            for suggestion in await displaySuggestions {
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
    }

    public func invalidateDisplaySuggestions(inGroup groupIndex: Int) async {
        let displaySuggestions = await displaySuggestions
        guard groupIndex < displaySuggestions.count, groupIndex >= 0 else { return }
        let suggestion = displaySuggestions[groupIndex]
        defer { onCodeSuggestionChange() }
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
        defer { onCodeSuggestionChange() }
        defaultSuggestionProvider.invalidateSuggestions(after: position)
        suggestionProviders.forEach { $0.invalidateSuggestions(after: position) }
    }

    public func updateCursorPosition(_ position: CursorPosition) {
        cursorPosition = position
    }

    @MainActor
    public func nextSuggestionGroup() {
        _displaySuggestions.offsetAnchor(1)
    }

    @MainActor
    public func nextSuggestionInGroup(index: Int) {
        if case var .group(group) = displaySuggestions[index] {
            group.offsetIndex(1)
            _displaySuggestions[index] = .group(group)
        }
    }

    @MainActor
    public func previousSuggestionGroup() {
        _displaySuggestions.offsetAnchor(-1)
    }

    @MainActor
    public func previousSuggestionInGroup(index: Int) {
        if case var .group(group) = displaySuggestions[index] {
            group.offsetIndex(-1)
            _displaySuggestions[index] = .group(group)
        }
    }
}

extension FileSuggestionManager: FilespaceSuggestionProviderDelegate {
    func onCodeSuggestionChange() {
        Task { await renderDisplaySuggestionsAtCursor() }
    }
}

public extension FileSuggestionManager {
    struct CircularSuggestionList: Sequence, Equatable {
        public static var empty: CircularSuggestionList {
            .init(suggestions: [], anchorId: nil)
        }

        public fileprivate(set) var suggestions: IdentifiedArrayOf<DisplaySuggestion> = []
        public private(set) var anchorId: String?
        public var anchorIndex: Int {
            guard let id = anchorId else { return 0 }
            return suggestions.firstIndex { $0.id == id } ?? 0
        }

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
                anchorId = nil
                return
            }
            let newIndex = anchorIndex + offset
            let anchorIndex = (newIndex + suggestions.count) % suggestions.count
            anchorId = suggestions[anchorIndex].id
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

        public var activeCodeSuggestion: CodeSuggestion? {
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
    func renderDisplaySuggestionsAtCursor() async {
        let suggestions = await collectDisplaySuggestionsAtCursor()
        await MainActor.run { _displaySuggestions.suggestions = suggestions }
    }

    func collectDisplaySuggestionsAtCursor() async -> IdentifiedArrayOf<DisplaySuggestion> {
        let existedGroupSuggestionIndices: [String: Int] = await MainActor.run {
            displaySuggestions.reduce(into: [:]) { result, suggestion in
                if case let .group(group) = suggestion {
                    result[group.id] = group.suggestionIndex
                }
            }
        }
        var groups = IdentifiedArrayOf<DisplayGroup>()
        var actions = IdentifiedArrayOf<DisplayAction>()
        let suggestions = await suggestions(
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


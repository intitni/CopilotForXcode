import Foundation
import SuggestionBasic

public struct CodeDiff {
    public init() {}
    
    public typealias LineDiff = CollectionDifference<String>

    public struct SnippetDiff: Equatable {
        public struct Change: Equatable {
            public var offset: Int
            public var element: String
        }

        public struct Line: Equatable {
            public enum Diff: Equatable {
                case unchanged
                case mutated(changes: [Change])
            }

            public var text: String
            public var diff: Diff = .unchanged
        }

        public struct Section: Equatable {
            public var oldSnippet: [Line]
            public var newSnippet: [Line]

            public var isEmpty: Bool {
                oldSnippet.isEmpty && newSnippet.isEmpty
            }
        }

        public var sections: [Section]

        public func line(at index: Int, in keyPath: KeyPath<Section, [Line]>) -> Line? {
            var previousSectionEnd = 0
            for section in sections {
                let lines = section[keyPath: keyPath]
                let index = index - previousSectionEnd
                if index < lines.endIndex {
                    return lines[index]
                }
                previousSectionEnd += lines.endIndex
            }
            return nil
        }
    }

    public func diff(text: String, from oldText: String) -> LineDiff {
        typealias Change = LineDiff.Change
        let diffByCharacter = text.difference(from: oldText)
        var result = [Change]()

        var current: Change?
        for item in diffByCharacter {
            if let this = current {
                switch (this, item) {
                case let (.insert(offset, element, associatedWith), .insert(offsetB, elementB, _))
                    where offset + element.count == offsetB:
                    current = .insert(
                        offset: offset,
                        element: element + String(elementB),
                        associatedWith: associatedWith
                    )
                    continue
                case let (.remove(offset, element, associatedWith), .remove(offsetB, elementB, _))
                    where offset - 1 == offsetB:
                    current = .remove(
                        offset: offsetB,
                        element: String(elementB) + element,
                        associatedWith: associatedWith
                    )
                    continue
                default:
                    result.append(this)
                }
            }

            current = switch item {
            case let .insert(offset, element, associatedWith):
                .insert(offset: offset, element: String(element), associatedWith: associatedWith)
            case let .remove(offset, element, associatedWith):
                .remove(offset: offset, element: String(element), associatedWith: associatedWith)
            }
        }

        if let current {
            result.append(current)
        }

        return .init(result) ?? [].difference(from: [])
    }

    public func diff(snippet: String, from oldSnippet: String) -> SnippetDiff {
        let newLines = snippet.splitByNewLine(omittingEmptySubsequences: false)
        let oldLines = oldSnippet.splitByNewLine(omittingEmptySubsequences: false)
        let diffByLine = newLines.difference(from: oldLines)

        let (insertions, removals) = generateDiffSections(
            oldLines: oldLines,
            newLines: newLines,
            diffByLine: diffByLine
        )

        var oldLineIndex = 0
        var newLineIndex = 0
        var sectionIndex = 0
        var result = SnippetDiff(sections: [])

        while oldLineIndex < oldLines.endIndex || newLineIndex < newLines.endIndex {
            let removalSection = removals[safe: sectionIndex]
            let insertionSection = insertions[safe: sectionIndex]

            // handle lines before sections
            var beforeSection = SnippetDiff.Section(oldSnippet: [], newSnippet: [])

            while oldLineIndex < (removalSection?.offset ?? oldLines.endIndex) {
                if oldLineIndex < oldLines.endIndex {
                    beforeSection.oldSnippet.append(.init(
                        text: String(oldLines[oldLineIndex]),
                        diff: .unchanged
                    ))
                }
                oldLineIndex += 1
            }
            while newLineIndex < (insertionSection?.offset ?? newLines.endIndex) {
                if newLineIndex < newLines.endIndex {
                    beforeSection.newSnippet.append(.init(
                        text: String(newLines[newLineIndex]),
                        diff: .unchanged
                    ))
                }
                newLineIndex += 1
            }

            if !beforeSection.isEmpty {
                result.sections.append(beforeSection)
            }

            // handle lines inside sections

            var insideSection = SnippetDiff.Section(oldSnippet: [], newSnippet: [])

            for i in 0..<max(removalSection?.lines.count ?? 0, insertionSection?.lines.count ?? 0) {
                let oldLine = removalSection?.lines[safe: i]
                let newLine = insertionSection?.lines[safe: i]
                let diff = diff(text: newLine ?? "", from: oldLine ?? "")
                if let oldLine {
                    insideSection.oldSnippet.append(.init(
                        text: oldLine,
                        diff: .mutated(changes: diff.removals.compactMap { change in
                            guard case let .remove(offset, element, _) = change else { return nil }
                            return .init(offset: offset, element: element)
                        })
                    ))
                }
                if let newLine {
                    insideSection.newSnippet.append(.init(
                        text: newLine,
                        diff: .mutated(changes: diff.insertions.compactMap { change in
                            guard case let .insert(offset, element, _) = change else { return nil }
                            return .init(offset: offset, element: element)
                        })
                    ))
                }
            }

            if !insideSection.isEmpty {
                result.sections.append(insideSection)
            }

            oldLineIndex += removalSection?.lines.count ?? 0
            newLineIndex += insertionSection?.lines.count ?? 0
            sectionIndex += 1
        }

        return result
    }
}

extension CodeDiff {
    struct DiffSection: Equatable {
        var offset: Int
        var end: Int
        var lines: [String]

        mutating func appendIfPossible(offset: Int, element: Substring) -> Bool {
            if end + 1 != offset { return false }
            end = offset
            lines.append(String(element))
            return true
        }
    }

    func generateDiffSections(
        oldLines: [Substring],
        newLines: [Substring],
        diffByLine: CollectionDifference<Substring>
    ) -> (insertionSections: [DiffSection], removalSections: [DiffSection]) {
        let insertionDiffs = diffByLine.insertions
        let removalDiffs = diffByLine.removals
        var insertions = [DiffSection]()
        var removals = [DiffSection]()
        var insertionIndex = 0
        var removalIndex = 0
        var insertionUnchangedGap = 0
        var removalUnchangedGap = 0

        while insertionIndex < insertionDiffs.endIndex || removalIndex < removalDiffs.endIndex {
            let insertion = insertionDiffs[safe: insertionIndex]
            let removal = removalDiffs[safe: removalIndex]

            append(
                into: &insertions,
                change: insertion,
                index: &insertionIndex,
                unchangedGap: &insertionUnchangedGap
            ) { change in
                guard case let .insert(offset, element, _) = change else { return nil }
                return (offset, element)
            }

            append(
                into: &removals,
                change: removal,
                index: &removalIndex,
                unchangedGap: &removalUnchangedGap
            ) { change in
                guard case let .remove(offset, element, _) = change else { return nil }
                return (offset, element)
            }

            if insertionUnchangedGap > removalUnchangedGap {
                // insert empty sections to insertions
                if removalUnchangedGap > 0 {
                    let count = insertionUnchangedGap - removalUnchangedGap
                    let index = max(insertions.endIndex - 1, 0)
                    let offset = (insertions.last?.offset ?? 0) - count
                    insertions.insert(
                        .init(offset: offset, end: offset, lines: []),
                        at: index
                    )
                    insertionUnchangedGap -= removalUnchangedGap
                    removalUnchangedGap = 0
                } else if removal == nil {
                    removalUnchangedGap = 0
                    insertionUnchangedGap = 0
                }
            } else if removalUnchangedGap > insertionUnchangedGap { 
                // insert empty sections to removals
                if insertionUnchangedGap > 0 {
                    let count = removalUnchangedGap - insertionUnchangedGap
                    let index = max(removals.endIndex - 1, 0)
                    let offset = (removals.last?.offset ?? 0) - count
                    removals.insert(
                        .init(offset: offset, end: offset, lines: []),
                        at: index
                    )
                    removalUnchangedGap -= insertionUnchangedGap
                    insertionUnchangedGap = 0
                } else {
                    removalUnchangedGap = 0
                    insertionUnchangedGap = 0
                }
            } else {
                removalUnchangedGap = 0
                insertionUnchangedGap = 0
            }
        }

        return (insertions, removals)
    }

    func append(
        into sections: inout [DiffSection],
        change: CollectionDifference<Substring>.Change?,
        index: inout Int,
        unchangedGap: inout Int,
        extract: (CollectionDifference<Substring>.Change) -> (offset: Int, line: Substring)?
    ) {
        guard let change, let (offset, element) = extract(change) else { return }
        if unchangedGap == 0 {
            if !sections.isEmpty {
                let lastIndex = sections.endIndex - 1
                if !sections[lastIndex]
                    .appendIfPossible(offset: offset, element: element)
                {
                    unchangedGap = offset - sections[lastIndex].end - 1
                    sections.append(.init(
                        offset: offset,
                        end: offset,
                        lines: [String(element)]
                    ))
                }
            } else {
                sections.append(.init(
                    offset: offset,
                    end: offset,
                    lines: [String(element)]
                ))
                unchangedGap = offset
            }
            index += 1
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }

    subscript(safe index: Int, fallback fallback: Element) -> Element {
        guard index >= 0, index < count else { return fallback }
        return self[index]
    }
}

#if DEBUG

import SwiftUI

struct SnippetDiffPreview: View {
    let originalCode: String
    let newCode: String

    var body: some View {
        HStack(alignment: .top) {
            let (original, new) = generateTexts()
            block(original)
            Divider()
            block(new)
        }
        .padding()
        .font(.body.monospaced())
    }

    @ViewBuilder
    func block(_ code: [AttributedString]) -> some View {
        VStack(alignment: .leading) {
            if !code.isEmpty {
                ForEach(0..<code.count, id: \.self) { index in
                    HStack {
                        Text("\(index)")
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                        Text(code[index])
                            .multilineTextAlignment(.leading)
                            .frame(minWidth: 260, alignment: .leading)
                    }
                }
            }
        }
    }

    func generateTexts() -> (original: [AttributedString], new: [AttributedString]) {
        let diff = CodeDiff().diff(snippet: newCode, from: originalCode)

        let new = diff.sections.flatMap {
            $0.newSnippet.map {
                let text = $0.text.trimmingCharacters(in: .newlines)
                let string = NSMutableAttributedString(string: text)
                if case let .mutated(changes) = $0.diff {
                    string.addAttribute(
                        .backgroundColor,
                        value: NSColor.green.withAlphaComponent(0.1),
                        range: NSRange(location: 0, length: text.count)
                    )

                    for diffItem in changes {
                        string.addAttribute(
                            .backgroundColor,
                            value: NSColor.green.withAlphaComponent(0.5),
                            range: NSRange(
                                location: diffItem.offset,
                                length: min(
                                    text.count - diffItem.offset,
                                    diffItem.element.count
                                )
                            )
                        )
                    }
                }
                return string
            }
        }

        let original = diff.sections.flatMap {
            $0.oldSnippet.map {
                let text = $0.text.trimmingCharacters(in: .newlines)
                let string = NSMutableAttributedString(string: text)
                if case let .mutated(changes) = $0.diff {
                    string.addAttribute(
                        .backgroundColor,
                        value: NSColor.red.withAlphaComponent(0.1),
                        range: NSRange(location: 0, length: text.count)
                    )

                    for diffItem in changes {
                        string.addAttribute(
                            .backgroundColor,
                            value: NSColor.red.withAlphaComponent(0.5),
                            range: NSRange(
                                location: diffItem.offset,
                                length: min(text.count - diffItem.offset, diffItem.element.count)
                            )
                        )
                    }
                }

                return string
            }
        }

        return (original.map(AttributedString.init), new.map(AttributedString.init))
    }
}

struct LineDiffPreview: View {
    let originalCode: String
    let newCode: String

    var body: some View {
        VStack(alignment: .leading) {
            let (original, new) = generateTexts()
            Text(original)
            Divider()
            Text(new)
        }
        .padding()
        .font(.body.monospaced())
    }

    func generateTexts() -> (original: AttributedString, new: AttributedString) {
        let diff = CodeDiff().diff(text: newCode, from: originalCode)
        let original = NSMutableAttributedString(string: originalCode)
        let new = NSMutableAttributedString(string: newCode)

        for item in diff {
            switch item {
            case let .insert(offset, element, _):
                new.addAttribute(
                    .backgroundColor,
                    value: NSColor.green.withAlphaComponent(0.5),
                    range: NSRange(location: offset, length: element.count)
                )
            case let .remove(offset, element, _):
                original.addAttribute(
                    .backgroundColor,
                    value: NSColor.red.withAlphaComponent(0.5),
                    range: NSRange(location: offset, length: element.count)
                )
            }
        }

        return (.init(original), .init(new))
    }
}

#Preview("Line Diff") {
    let originalCode = """
    let foo = Foo() // yes
    """
    let newCode = """
    var foo = Bar()
    """

    return LineDiffPreview(originalCode: originalCode, newCode: newCode)
}

#Preview("Snippet Diff") {
    let originalCode = """
    let foo = Foo()
    print(foo)
    // do something
    foo.foo()
    func zoo() {}
    """
    let newCode = """
    var foo = Bar()
    // do something
    foo.bar()
    func zoo() {
        print("zoo")
    }
    """

    return SnippetDiffPreview(originalCode: originalCode, newCode: newCode)
}

#endif


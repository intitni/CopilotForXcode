import Foundation
import SuggestionBasic

public struct CodeDiff {
    public init() {}

    public typealias LineDiff = CollectionDifference<String>

    public struct SnippetDiff: Equatable, CustomStringConvertible {
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

            var description: String {
                switch diff {
                case .unchanged:
                    return text
                case let .mutated(changes):
                    return text + "   [" + changes.map { change in
                        "\(change.offset): \(change.element)"
                    }.joined(separator: " | ") + "]"
                }
            }
        }

        public struct Section: Equatable, CustomStringConvertible {
            public var oldOffset: Int
            public var newOffset: Int
            public var oldSnippet: [Line]
            public var newSnippet: [Line]

            public var isEmpty: Bool {
                oldSnippet.isEmpty && newSnippet.isEmpty
            }

            public var description: String {
                """
                \(oldSnippet.enumerated().compactMap { item in
                    let (index, line) = item
                    let lineIndex = String(format: "%3d", oldOffset + index + 1) + "   "
                    switch line.diff {
                    case .unchanged:
                        return "\(lineIndex)|    \(line.description)"
                    case .mutated:
                        return "\(lineIndex)| -  \(line.description)"
                    }
                }.joined(separator: "\n"))
                \(newSnippet.enumerated().map { item in
                    let (index, line) = item
                    let lineIndex = "   " + String(format: "%3d", newOffset + index + 1)
                    switch line.diff {
                    case .unchanged:
                        return "\(lineIndex)|    \(line.description)"
                    case .mutated:
                        return "\(lineIndex)| +  \(line.description)"
                    }
                }.joined(separator: "\n"))
                """
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

        public var description: String {
            "Diff:\n" + sections.map(\.description).joined(separator: "\n---\n") + "\n"
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

        let groups = generateDiffSections(diffByLine)

        var oldLineIndex = 0
        var newLineIndex = 0
        var sectionIndex = 0
        var result = SnippetDiff(sections: [])

        while oldLineIndex < oldLines.endIndex || newLineIndex < newLines.endIndex {
            guard let groupItem = groups[safe: sectionIndex] else {
                let finishingSection = SnippetDiff.Section(
                    oldOffset: oldLineIndex,
                    newOffset: newLineIndex,
                    oldSnippet: {
                        guard oldLineIndex < oldLines.endIndex else { return [] }
                        return oldLines[oldLineIndex..<oldLines.endIndex].map {
                            .init(text: String($0), diff: .unchanged)
                        }
                    }(),
                    newSnippet: {
                        guard newLineIndex < newLines.endIndex else { return [] }
                        return newLines[newLineIndex..<newLines.endIndex].map {
                            .init(text: String($0), diff: .unchanged)
                        }
                    }()
                )

                if !finishingSection.isEmpty {
                    result.sections.append(finishingSection)
                }

                break
            }

            let unchangedLines: [SnippetDiff.Line] = {
                var all = [SnippetDiff.Line]()
                if let offset = groupItem.remove.first?.offset {
                    var line = oldLineIndex
                    while line < offset {
                        if line < oldLines.endIndex {
                            all.append(.init(text: String(oldLines[line]), diff: .unchanged))
                        }
                        line += 1
                    }
                } else if let offset = groupItem.insert.first?.offset {
                    var line = newLineIndex
                    while line < offset {
                        if line < newLines.endIndex {
                            all.append(.init(text: String(newLines[line]), diff: .unchanged))
                        }
                        line += 1
                    }
                }
                return all
            }()
 
            // handle lines before sections
            let beforeSection = SnippetDiff.Section(
                oldOffset: oldLineIndex,
                newOffset: newLineIndex,
                oldSnippet: unchangedLines,
                newSnippet: unchangedLines
            )
            
            oldLineIndex += unchangedLines.count
            newLineIndex += unchangedLines.count

            if !beforeSection.isEmpty {
                result.sections.append(beforeSection)
            }

            // handle lines inside sections

            var insideSection = SnippetDiff.Section(
                oldOffset: oldLineIndex,
                newOffset: newLineIndex,
                oldSnippet: [],
                newSnippet: []
            )

            for i in 0..<max(groupItem.remove.count, groupItem.insert.count) {
                let oldLine = (groupItem.remove[safe: i]?.element).map(String.init)
                let newLine = (groupItem.insert[safe: i]?.element).map(String.init)
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

            oldLineIndex += groupItem.remove.count
            newLineIndex += groupItem.insert.count
            sectionIndex += 1

            if !insideSection.isEmpty {
                result.sections.append(insideSection)
            }
        }

        return result
    }
}

private extension CodeDiff {
    func generateDiffSections(_ diff: CollectionDifference<Substring>)
        -> [DiffGroupItem<Substring>]
    {
        guard !diff.isEmpty else { return [] }

        let removes = ChangeSection.sectioning(diff.removals)
        let inserts = ChangeSection.sectioning(diff.insertions)

        var groups = [DiffGroupItem<Substring>]()

        var removeOffset = 0
        var insertOffset = 0
        var removeIndex = 0
        var insertIndex = 0

        while removeIndex < removes.count || insertIndex < inserts.count {
            let removeSection = removes[safe: removeIndex]
            let insertSection = inserts[safe: insertIndex]

            if let removeSection, let insertSection {
                let ro = removeSection.offset - removeOffset
                let io = insertSection.offset - insertOffset
                if ro == io {
                    groups.append(.init(
                        remove: removeSection.changes.map { .init(change: $0) },
                        insert: insertSection.changes.map { .init(change: $0) }
                    ))
                    removeOffset += removeSection.changes.count
                    insertOffset += insertSection.changes.count
                    removeIndex += 1
                    insertIndex += 1
                } else if ro < io {
                    groups.append(.init(
                        remove: removeSection.changes.map { .init(change: $0) },
                        insert: []
                    ))
                    removeOffset += removeSection.changes.count
                    removeIndex += 1
                } else {
                    groups.append(.init(
                        remove: [],
                        insert: insertSection.changes.map { .init(change: $0) }
                    ))
                    insertOffset += insertSection.changes.count
                    insertIndex += 1
                }
            } else if let removeSection {
                groups.append(.init(
                    remove: removeSection.changes.map { .init(change: $0) },
                    insert: []
                ))
                removeIndex += 1
            } else if let insertSection {
                groups.append(.init(
                    remove: [],
                    insert: insertSection.changes.map { .init(change: $0) }
                ))
                insertIndex += 1
            }
        }

        return groups
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }

    subscript(safe index: Int, fallback fallback: Element) -> Element {
        guard index >= 0, index < count else { return fallback }
        return self[index]
    }
}

private extension CollectionDifference.Change {
    var offset: Int {
        switch self {
        case let .insert(offset, _, _):
            return offset
        case let .remove(offset, _, _):
            return offset
        }
    }
}

private struct DiffGroupItem<Element> {
    struct Item {
        var offset: Int
        var element: Element

        init(offset: Int, element: Element) {
            self.offset = offset
            self.element = element
        }

        init(change: CollectionDifference<Element>.Change) {
            offset = change.offset
            switch change {
            case let .insert(_, element, _):
                self.element = element
            case let .remove(_, element, _):
                self.element = element
            }
        }
    }

    var remove: [Item]
    var insert: [Item]
}

private struct ChangeSection<Element> {
    var offset: Int { changes.first?.offset ?? 0 }
    var changes: [CollectionDifference<Element>.Change]

    static func sectioning(_ changes: [CollectionDifference<Element>.Change]) -> [Self] {
        guard !changes.isEmpty else { return [] }

        let sortedChanges = changes.sorted { $0.offset < $1.offset }
        var sections = [Self]()
        var currentSection = [CollectionDifference<Element>.Change]()

        for change in sortedChanges {
            if let lastOffset = currentSection.last?.offset {
                if change.offset == lastOffset + 1 {
                    currentSection.append(change)
                } else {
                    sections.append(Self(changes: currentSection))
                    currentSection.removeAll()
                    currentSection.append(change)
                }
            } else {
                currentSection.append(change)
                continue
            }
        }

        if !currentSection.isEmpty {
            sections.append(Self(changes: currentSection))
        }

        return sections
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

#Preview("Code Diff Editor") {
    struct V: View {
        @State var originalCode = ""
        @State var newCode = ""

        var body: some View {
            VStack {
                HStack {
                    VStack {
                        Text("Original")
                        TextEditor(text: $originalCode)
                            .frame(width: 300, height: 200)
                    }
                    VStack {
                        Text("New")
                        TextEditor(text: $newCode)
                            .frame(width: 300, height: 200)
                    }
                }
                .font(.body.monospaced())
                SnippetDiffPreview(originalCode: originalCode, newCode: newCode)
            }
            .padding()
            .frame(height: 600)
        }
    }

    return V()
}

#endif


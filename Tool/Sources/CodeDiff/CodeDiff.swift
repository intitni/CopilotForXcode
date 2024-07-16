import Foundation
import SuggestionBasic

public struct CodeDiff {
    public typealias LineDiff = CollectionDifference<String>

    public struct SnippetDiff {
        public struct Change {
            public var offset: Int
            public var element: String
        }

        public struct Line {
            public var text: String
            public var diff: [Change]?
        }

        public struct Section {
            public var oldSnippet: [Line]
            public var newSnippet: [Line]
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
        let newLines = snippet.breakLines()
        let oldLines = oldSnippet.breakLines()
        let diffByLine = newLines.difference(from: oldLines)

        struct DiffSection: Equatable {
            var offset: Int
            var end: Int
            var lines: [String]
        }

        func collect(
            into all: inout [DiffSection],
            changes: [CollectionDifference<String>.Change],
            extract: (CollectionDifference<String>.Change) -> (offset: Int, line: String)?
        ) {
            var current: DiffSection?
            for change in changes {
                guard let (offset, element) = extract(change) else { continue }
                if var section = current {
                    if offset == section.end + 1 {
                        section.lines.append(element)
                        section.end = offset
                        current = section
                        continue
                    } else {
                        all.append(section)
                    }
                }

                current = DiffSection(offset: offset, end: offset, lines: [element])
            }

            if let current {
                all.append(current)
            }
        }

        var insertions = [DiffSection]()
        var removals = [DiffSection]()

        collect(into: &removals, changes: diffByLine.removals) { change in
            guard case let .remove(offset, element, _) = change else { return nil }
            return (offset, element)
        }

        collect(into: &insertions, changes: diffByLine.insertions) { change in
            guard case let .insert(offset, element, _) = change else { return nil }
            return (offset, element)
        }

        var oldLineIndex = 0
        var newLineIndex = 0
        var sectionIndex = 0
        var result = SnippetDiff(sections: [])

        while oldLineIndex < oldLines.endIndex || newLineIndex < newLines.endIndex {
            let removalSection = removals[safe: sectionIndex]
            let insertionSection = insertions[safe: sectionIndex]

            // handle lines before sections
            var beforeSection = SnippetDiff.Section(oldSnippet: [], newSnippet: [])

            while oldLineIndex < (removalSection?.offset ?? .max) {
                beforeSection.oldSnippet.append(.init(text: oldLines[oldLineIndex], diff: nil))
                oldLineIndex += 1
            }
            while newLineIndex < (insertionSection?.offset ?? .max) {
                beforeSection.newSnippet.append(.init(text: newLines[newLineIndex], diff: nil))
                newLineIndex += 1
            }

            result.sections.append(beforeSection)

            // handle lines inside sections

            var insideSection = SnippetDiff.Section(oldSnippet: [], newSnippet: [])

            for i in 0..<max(removalSection?.lines.count ?? 0, insertionSection?.lines.count ?? 0) {
                let oldLine = removalSection?.lines[safe: i]
                let newLine = insertionSection?.lines[safe: i]
                let diff = diff(text: newLine ?? "", from: oldLine ?? "")
                if let oldLine {
                    insideSection.oldSnippet.append(.init(
                        text: oldLine,
                        diff: diff.removals.compactMap { change in
                            guard case let .remove(offset, element, _) = change else { return nil }
                            return .init(offset: offset, element: element)
                        }
                    ))
                }
                if let newLine {
                    insideSection.newSnippet.append(.init(
                        text: newLine,
                        diff: diff.insertions.compactMap { change in
                            guard case let .insert(offset, element, _) = change else { return nil }
                            return .init(offset: offset, element: element)
                        }
                    ))
                }
            }

            result.sections.append(insideSection)

            oldLineIndex += removalSection?.lines.count ?? 0
            newLineIndex += insertionSection?.lines.count ?? 0
            sectionIndex += 1
        }

        return result
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
                if let diff = $0.diff {
                    string.addAttribute(
                        .backgroundColor,
                        value: NSColor.green.withAlphaComponent(0.1),
                        range: NSRange(location: 0, length: text.count)
                    )

                    for diffItem in diff {
                        string.addAttribute(
                            .backgroundColor,
                            value: NSColor.green.withAlphaComponent(0.5),
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

        let original = diff.sections.flatMap {
            $0.oldSnippet.map {
                let text = $0.text.trimmingCharacters(in: .newlines)
                let string = NSMutableAttributedString(string: text)
                if let diff = $0.diff {
                    string.addAttribute(
                        .backgroundColor,
                        value: NSColor.red.withAlphaComponent(0.1),
                        range: NSRange(location: 0, length: text.count)
                    )

                    for diffItem in diff {
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


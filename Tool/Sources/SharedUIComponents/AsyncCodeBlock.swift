import CodeDiff
import DebounceFunction
import Foundation
import Perception
import SwiftUI

public struct AsyncCodeBlock: View { // chat: hid
    @State var storage = Storage()
    @Environment(\.colorScheme) var colorScheme

    /// If original code is provided, diff will be generated.
    let originalCode: String?
    /// The code to present.
    let code: String
    /// The language of the code.
    let language: String
    /// The index of the first line.
    let startLineIndex: Int
    /// The scenario of the code block.
    let scenario: String
    /// The font of the code block.
    let font: NSFont
    /// The default foreground color of the code block.
    let proposedForegroundColor: Color?
    /// The ranges to dim in the code.
    let dimmedCharacterCount: DimmedCharacterCount
    /// Whether to drop common leading spaces of each line.
    let droppingLeadingSpaces: Bool
    /// Whether to ignore whole line change in diff.
    let ignoreWholeLineChangeInDiff: Bool

    public init(
        code: String,
        originalCode: String? = nil,
        language: String,
        startLineIndex: Int,
        scenario: String,
        font: NSFont,
        droppingLeadingSpaces: Bool,
        proposedForegroundColor: Color?,
        dimmedCharacterCount: DimmedCharacterCount = .init(prefix: 0, suffix: 0),
        ignoreWholeLineChangeInDiff: Bool = true
    ) {
        self.code = code
        self.originalCode = originalCode
        self.startLineIndex = startLineIndex
        self.language = language
        self.scenario = scenario
        self.font = font
        self.proposedForegroundColor = proposedForegroundColor
        self.dimmedCharacterCount = dimmedCharacterCount
        self.droppingLeadingSpaces = droppingLeadingSpaces
        self.ignoreWholeLineChangeInDiff = ignoreWholeLineChangeInDiff
    }

    var foregroundColor: Color {
        proposedForegroundColor ?? (colorScheme == .dark ? .white : .black)
    }

    public var body: some View {
        WithPerceptionTracking {
            let commonPrecedingSpaceCount = storage.highlightStorage.commonPrecedingSpaceCount
            VStack(spacing: 2) {
                ForEach(Array(storage.highlightedContent.enumerated()), id: \.0) { item in
                    let (index, attributedString) = item
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(index + startLineIndex + 1)")
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(foregroundColor.opacity(0.5))
                            .frame(minWidth: 40)
                        Text(AttributedString(attributedString))
                            .foregroundColor(foregroundColor.opacity(0.3))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                            .overlay(alignment: .topLeading) {
                                if index == 0, commonPrecedingSpaceCount > 0 {
                                    Text("\(commonPrecedingSpaceCount + 1)")
                                        .padding(.top, -12)
                                        .font(.footnote)
                                        .foregroundStyle(foregroundColor)
                                        .opacity(0.3)
                                }
                            }
                    }
                }
            }
            .foregroundColor(.white)
            .font(.init(font))
            .padding(.leading, 4)
            .padding(.trailing)
            .padding(.top, commonPrecedingSpaceCount > 0 ? 16 : 4)
            .padding(.bottom, 4)
            .onAppear {
                storage.dimmedCharacterCount = dimmedCharacterCount
                storage.ignoreWholeLineChangeInDiff = ignoreWholeLineChangeInDiff
                storage.highlightStorage.highlight(debounce: false, for: self)
                storage.diffStorage.diff(for: self)
            }
            .onChange(of: code) { code in
                storage.code = code
                storage.highlightStorage.highlight(debounce: true, for: self)
                storage.diffStorage.diff(for: self)
            }
            .onChange(of: originalCode) { originalCode in
                storage.originalCode = originalCode
                storage.diffStorage.diff(for: self)
            }
            .onChange(of: colorScheme) { _ in
                storage.highlightStorage.highlight(debounce: true, for: self)
            }
            .onChange(of: droppingLeadingSpaces) { _ in
                storage.highlightStorage.highlight(debounce: true, for: self)
            }
            .onChange(of: scenario) { _ in
                storage.highlightStorage.highlight(debounce: true, for: self)
            }
            .onChange(of: language) { _ in
                storage.highlightStorage.highlight(debounce: true, for: self)
            }
            .onChange(of: proposedForegroundColor) { _ in
                storage.highlightStorage.highlight(debounce: true, for: self)
            }
            .onChange(of: dimmedCharacterCount) { value in
                storage.dimmedCharacterCount = value
            }
            .onChange(of: ignoreWholeLineChangeInDiff) { value in
                storage.ignoreWholeLineChangeInDiff = value
            }
        }
    }
}

// MARK: - Storage

extension AsyncCodeBlock {
    static let queue = DispatchQueue(
        label: "code-block-highlight",
        qos: .userInteractive,
        attributes: .concurrent
    )

    public struct DimmedCharacterCount: Equatable {
        public var prefix: Int
        public var suffix: Int
        public init(prefix: Int, suffix: Int) {
            self.prefix = prefix
            self.suffix = suffix
        }
    }

    @Perceptible
    class Storage {
        var dimmedCharacterCount: DimmedCharacterCount = .init(prefix: 0, suffix: 0)
        let diffStorage = DiffStorage()
        let highlightStorage = HighlightStorage()
        var ignoreWholeLineChangeInDiff: Bool = true

        var code: String? {
            get { highlightStorage.code }
            set {
                highlightStorage.code = newValue
                diffStorage.code = newValue
            }
        }

        var originalCode: String? {
            get { diffStorage.originalCode }
            set { diffStorage.originalCode = newValue }
        }

        var highlightedContent: [NSAttributedString] {
            let commonPrecedingSpaceCount = highlightStorage.commonPrecedingSpaceCount
            let highlightedCode = highlightStorage.highlightedCode
                .map(NSMutableAttributedString.init(attributedString:))

            Self.dim(
                highlightedCode,
                commonPrecedingSpaceCount: commonPrecedingSpaceCount,
                dimmedCharacterCount: dimmedCharacterCount
            )

            if let diffResult = diffStorage.diffResult {
                Self.presentDiff(
                    highlightedCode,
                    commonPrecedingSpaceCount: commonPrecedingSpaceCount,
                    ignoreWholeLineChange: ignoreWholeLineChangeInDiff,
                    diffResult: diffResult
                )
            }

            return highlightedCode
        }

        static func dim(
            _ highlightedCode: [NSMutableAttributedString],
            commonPrecedingSpaceCount: Int,
            dimmedCharacterCount: DimmedCharacterCount
        ) {
            func dim(
                _ line: NSMutableAttributedString,
                in targetRange: Range<String.Index>,
                opacity: Double
            ) {
                let targetRange = NSRange(targetRange, in: line.string)
                line.enumerateAttribute(
                    .foregroundColor,
                    in: NSRange(location: 0, length: line.length)
                ) { value, range, _ in
                    guard let color = value as? NSColor else { return }
                    let opacity = max(0.1, color.alphaComponent * opacity)
                    let intersection = NSIntersectionRange(targetRange, range)
                    guard !(intersection.length == 0) else { return }
                    let rangeA = intersection
                    line.addAttribute(
                        .foregroundColor,
                        value: color.withAlphaComponent(opacity),
                        range: rangeA
                    )

                    let rangeB = NSRange(
                        location: intersection.upperBound,
                        length: range.upperBound - intersection.upperBound
                    )
                    line.addAttribute(
                        .foregroundColor,
                        value: color,
                        range: rangeB
                    )
                }
            }

            if dimmedCharacterCount.prefix > commonPrecedingSpaceCount,
               let firstLine = highlightedCode.first
            {
                let dimmedCount = dimmedCharacterCount.prefix - commonPrecedingSpaceCount
                let startIndex = firstLine.string.startIndex
                let endIndex = firstLine.string.utf16.index(
                    startIndex,
                    offsetBy: min(firstLine.length, max(0, dimmedCount)),
                    limitedBy: firstLine.string.endIndex
                ) ?? firstLine.string.endIndex
                if endIndex > startIndex {
                    dim(firstLine, in: startIndex..<endIndex, opacity: 0.4)
                }
            }

            if let lastLine = highlightedCode.last {
                let endIndex = lastLine.string.endIndex
                let startIndex = lastLine.string.utf16.index(
                    endIndex,
                    offsetBy: -dimmedCharacterCount.suffix,
                    limitedBy: lastLine.string.startIndex
                ) ?? lastLine.string.endIndex
                if startIndex < endIndex {
                    dim(lastLine, in: startIndex..<endIndex, opacity: 0.2)
                }
            }
        }

        static func presentDiff(
            _ highlightedCode: [NSMutableAttributedString],
            commonPrecedingSpaceCount: Int,
            ignoreWholeLineChange: Bool,
            diffResult: CodeDiff.SnippetDiff
        ) {
            let originalCodeIsSingleLine = diffResult.sections.count == 1
                && diffResult.sections[0].oldSnippet.count <= 1
            if !originalCodeIsSingleLine {
                for (index, mutableString) in highlightedCode.enumerated() {
                    guard let line = diffResult.line(at: index, in: \.newSnippet),
                          case let .mutated(changes) = line.diff, !changes.isEmpty
                    else { continue }

                    for change in changes {
                        if change.offset == 0,
                           change.element.count - commonPrecedingSpaceCount
                           == mutableString.string.count
                        {
                            if ignoreWholeLineChange {
                                continue
                            }
                        }

                        let offset = change.offset - commonPrecedingSpaceCount
                        let range = NSRange(
                            location: max(0, offset),
                            length: max(0, change.element.count + (offset < 0 ? offset : 0))
                        )
                        if range.location + range.length > mutableString.length {
                            continue
                        }
                        mutableString.addAttributes([
                            .backgroundColor: NSColor.systemGreen.withAlphaComponent(0.2),
                        ], range: range)
                    }
                }
            } else if let firstMutableString = highlightedCode.first,
                      let oldLine = diffResult.line(at: 0, in: \.oldSnippet),
                      oldLine.text.count > commonPrecedingSpaceCount
            {
                // Only highlight the diffs inside the dimmed area
                let scopeRange = NSRange(
                    location: 0,
                    length: min(
                        oldLine.text.count - commonPrecedingSpaceCount,
                        firstMutableString.length
                    )
                )
                if let line = diffResult.line(at: 0, in: \.newSnippet),
                   case let .mutated(changes) = line.diff, !changes.isEmpty
                {
                    for change in changes {
                        let offset = change.offset - commonPrecedingSpaceCount
                        let range = NSRange(
                            location: max(0, offset),
                            length: max(0, change.element.count + (offset < 0 ? offset : 0))
                        )
                        guard let limitedRange = limitRange(range, inside: scopeRange)
                        else { continue }
                        firstMutableString.addAttributes([
                            .backgroundColor: NSColor.systemGreen.withAlphaComponent(0.2),
                        ], range: limitedRange)
                    }
                }
            }

            let lastLineIndex = highlightedCode.endIndex - 1
            if lastLineIndex >= 0 {
                if let line = diffResult.line(at: lastLineIndex, in: \.oldSnippet),
                   case let .mutated(changes) = line.diff,
                   changes.count == 1,
                   let change = changes.last,
                   change.offset + change.element.count == line.text.count
                {
                    let lastLine = highlightedCode[lastLineIndex]
                    lastLine.append(.init(string: String(change.element), attributes: [
                        .foregroundColor: NSColor.systemRed.withAlphaComponent(0.5),
                        .backgroundColor: NSColor.systemRed.withAlphaComponent(0.2),
                    ]))
                }
            }
        }
    }

    @Perceptible
    class DiffStorage {
        private(set) var diffResult: CodeDiff.SnippetDiff?

        @PerceptionIgnored var originalCode: String?
        @PerceptionIgnored var code: String?
        @PerceptionIgnored private var diffTask: Task<Void, Error>?

        func diff(for view: AsyncCodeBlock) {
            performDiff(for: view)
        }

        private func performDiff(for view: AsyncCodeBlock) {
            diffTask?.cancel()
            let code = code ?? view.code
            guard let originalCode = originalCode ?? view.originalCode else {
                diffResult = nil
                return
            }

            diffTask = Task {
                let result = await withUnsafeContinuation { continuation in
                    AsyncCodeBlock.queue.async {
                        let result = CodeDiff().diff(snippet: code, from: originalCode)
                        continuation.resume(returning: result)
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    diffResult = result
                }
            }
        }
    }

    @Perceptible
    class HighlightStorage {
        private(set) var highlightedCode = [NSAttributedString]()
        private(set) var commonPrecedingSpaceCount = 0

        @PerceptionIgnored var code: String?
        @PerceptionIgnored private var foregroundColor: Color = .primary
        @PerceptionIgnored private var debounceFunction: DebounceFunction<AsyncCodeBlock>?
        @PerceptionIgnored private var highlightTask: Task<Void, Error>?

        init() {
            debounceFunction = .init(duration: 0.1, block: { view in
                self.highlight(for: view)
            })
        }

        func highlight(debounce: Bool, for view: AsyncCodeBlock) {
            if debounce {
                Task { @MainActor in await debounceFunction?(view) }
            } else {
                highlight(for: view)
            }
        }

        private func highlight(for view: AsyncCodeBlock) {
            highlightTask?.cancel()
            let code = self.code ?? view.code
            let language = view.language
            let scenario = view.scenario
            let brightMode = view.colorScheme != .dark
            let droppingLeadingSpaces = view.droppingLeadingSpaces
            foregroundColor = view.foregroundColor

            if highlightedCode.isEmpty {
                let content = CodeHighlighting.convertToCodeLines(
                    .init(string: code),
                    middleDotColor: brightMode
                        ? NSColor.black.withAlphaComponent(0.1)
                        : NSColor.white.withAlphaComponent(0.1),
                    droppingLeadingSpaces: droppingLeadingSpaces,
                    replaceSpacesWithMiddleDots: true
                )
                highlightedCode = content.code
                commonPrecedingSpaceCount = content.commonLeadingSpaceCount
            }

            highlightTask = Task {
                let result = await withUnsafeContinuation { continuation in
                    AsyncCodeBlock.queue.async {
                        let font = view.font
                        let content = CodeHighlighting.highlighted(
                            code: code,
                            language: language,
                            scenario: scenario,
                            brightMode: brightMode,
                            droppingLeadingSpaces: droppingLeadingSpaces,
                            font: font
                        )
                        continuation.resume(returning: content)
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    self.highlightedCode = result.0
                    self.commonPrecedingSpaceCount = result.1
                }
            }
        }
    }

    static func limitRange(_ nsRange: NSRange, inside another: NSRange) -> NSRange? {
        let intersection = NSIntersectionRange(nsRange, another)
        guard intersection.length > 0 else { return nil }
        return intersection
    }
}

#Preview("Single Line Suggestion") {
    AsyncCodeBlock(
        code: "    let foo = Bar()",
        originalCode: "    var foo // comment",
        language: "swift",
        startLineIndex: 10,
        scenario: "",
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        droppingLeadingSpaces: true,
        proposedForegroundColor: .primary,
        dimmedCharacterCount: .init(prefix: 11, suffix: 0)
    )
    .frame(width: 400, height: 100)
}

#Preview("Single Line Suggestion / Appending Suffix") {
    AsyncCodeBlock(
        code: "    let foo = Bar() // comment",
        originalCode: "    var foo // comment",
        language: "swift",
        startLineIndex: 10,
        scenario: "",
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        droppingLeadingSpaces: true,
        proposedForegroundColor: .primary,
        dimmedCharacterCount: .init(prefix: 11, suffix: 11)
    )
    .frame(width: 400, height: 100)
}

#Preview("Multiple Line Suggestion") {
    AsyncCodeBlock(
        code: "    let foo = Bar()\n    print(foo)",
        originalCode: "    var foo // comment\n    print(bar)",
        language: "swift",
        startLineIndex: 10,
        scenario: "",
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        droppingLeadingSpaces: true,
        proposedForegroundColor: .primary,
        dimmedCharacterCount: .init(prefix: 11, suffix: 0)
    )
    .frame(width: 400, height: 100)
}

#Preview("Multiple Line Suggestion Including Whole Line Change in Diff") {
    AsyncCodeBlock(
        code: "// comment\n    let foo = Bar()\n    print(bar)\n    print(foo)",
        originalCode: "    let foo = Bar()\n",
        language: "swift",
        startLineIndex: 10,
        scenario: "",
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        droppingLeadingSpaces: true,
        proposedForegroundColor: .primary,
        dimmedCharacterCount: .init(prefix: 11, suffix: 0),
        ignoreWholeLineChangeInDiff: false
    )
    .frame(width: 400, height: 100)
}

#Preview("Updating Content") {
    struct UpdateContent: View {
        @State var index = 0
        struct Case {
            let code: String
            let originalCode: String
        }

        let cases: [Case] = [
            .init(code: "foo(123)\nprint(foo)", originalCode: "bar(234)\nprint(bar)"),
            .init(code: "bar(456)", originalCode: "baz(567)"),
        ]

        var body: some View {
            VStack {
                Button("Update") {
                    index = (index + 1) % cases.count
                }
                AsyncCodeBlock(
                    code: cases[index].code,
                    originalCode: cases[index].originalCode,
                    language: "swift",
                    startLineIndex: 10,
                    scenario: "",
                    font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                    droppingLeadingSpaces: true,
                    proposedForegroundColor: .primary,
                    dimmedCharacterCount: .init(prefix: 0, suffix: 0)
                )
            }
        }
    }

    return UpdateContent()
        .frame(width: 400, height: 200)
}


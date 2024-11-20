import CodeDiff
import DebounceFunction
import Foundation
import Perception
import SwiftUI

public struct AsyncDiffCodeBlock: View {
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
    /// Whether to drop common leading spaces of each line.
    let droppingLeadingSpaces: Bool
    /// Whether to render the last diff section that only contains removals.
    let skipLastOnlyRemovalSection: Bool

    public init(
        code: String,
        originalCode: String? = nil,
        language: String,
        startLineIndex: Int,
        scenario: String,
        font: NSFont,
        droppingLeadingSpaces: Bool,
        proposedForegroundColor: Color?,
        ignoreWholeLineChangeInDiff: Bool = true,
        skipLastOnlyRemovalSection: Bool = false
    ) {
        self.code = code
        self.originalCode = originalCode
        self.startLineIndex = startLineIndex
        self.language = language
        self.scenario = scenario
        self.font = font
        self.proposedForegroundColor = proposedForegroundColor
        self.droppingLeadingSpaces = droppingLeadingSpaces
        self.skipLastOnlyRemovalSection = skipLastOnlyRemovalSection
    }

    var foregroundColor: Color {
        proposedForegroundColor ?? (colorScheme == .dark ? .white : .black)
    }

    public var body: some View {
        WithPerceptionTracking {
            let commonPrecedingSpaceCount = storage.highlightStorage.commonPrecedingSpaceCount
            VStack(spacing: 0) {
                lines
            }
            .foregroundColor(.white)
            .font(.init(font))
            .padding(.leading, 4)
            .padding(.trailing)
            .padding(.top, commonPrecedingSpaceCount > 0 ? 16 : 4)
            .padding(.bottom, 4)
            .onAppear {
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
            .onChange(of: skipLastOnlyRemovalSection) { _ in
                storage.skipLastOnlyRemovalSection = skipLastOnlyRemovalSection
            }
        }
    }

    @ViewBuilder
    var lines: some View {
        WithPerceptionTracking {
            let commonPrecedingSpaceCount = storage.highlightStorage.commonPrecedingSpaceCount
            ForEach(storage.highlightedContent) { line in
                LineView(
                    isFirstLine: line.id == storage.highlightedContent.first?.id,
                    commonPrecedingSpaceCount: commonPrecedingSpaceCount,
                    line: line,
                    startLineIndex: startLineIndex,
                    foregroundColor: foregroundColor
                )
            }
        }
    }

    struct LineView: View {
        let isFirstLine: Bool
        let commonPrecedingSpaceCount: Int
        let line: Storage.Line
        let startLineIndex: Int
        let foregroundColor: Color

        var body: some View {
            let attributedString = line.string
            let lineIndex = line.index + startLineIndex + 1
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(lineIndex)")
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(foregroundColor.opacity(0.5))
                    .frame(minWidth: 40)
                Text(AttributedString(attributedString))
                    .foregroundColor(foregroundColor.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .overlay(alignment: .topLeading) {
                        if isFirstLine, commonPrecedingSpaceCount > 0 {
                            Text("\(commonPrecedingSpaceCount + 1)")
                                .padding(.top, -12)
                                .font(.footnote)
                                .foregroundStyle(foregroundColor)
                                .opacity(0.3)
                        }
                    }
            }
            .padding(.vertical, 1)
            .background(
                line.kind == .added ? Color.green.opacity(0.2) : line
                    .kind == .deleted ? Color.red.opacity(0.2) : nil
            )
        }
    }
}

// MARK: - Storage

extension AsyncDiffCodeBlock {
    nonisolated static let queue = DispatchQueue(
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
        let diffStorage = DiffStorage()
        let highlightStorage = HighlightStorage()
        var skipLastOnlyRemovalSection: Bool = false

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

        struct Line: Identifiable {
            enum Kind {
                case added
                case deleted
                case unchanged
            }

            let index: Int
            let kind: Kind
            let string: NSAttributedString

            var id: String { "\(index)-\(kind)-\(string.string)" }
        }

        var highlightedContent: [Line] {
            let commonPrecedingSpaceCount = highlightStorage.commonPrecedingSpaceCount
            let highlightedCode = highlightStorage.highlightedCode
            let highlightedOriginalCode = highlightStorage.highlightedOriginalCode

            if let diffResult = diffStorage.diffResult {
                return Self.presentDiff(
                    new: highlightedCode,
                    original: highlightedOriginalCode,
                    commonPrecedingSpaceCount: commonPrecedingSpaceCount,
                    skipLastOnlyRemovalSection: skipLastOnlyRemovalSection,
                    diffResult: diffResult
                )
            }

            return highlightedCode.enumerated().map {
                Line(index: $0, kind: .unchanged, string: $1)
            }
        }

        static func presentDiff(
            new highlightedCode: [NSAttributedString],
            original originalHighlightedCode: [NSAttributedString],
            commonPrecedingSpaceCount: Int,
            skipLastOnlyRemovalSection: Bool,
            diffResult: CodeDiff.SnippetDiff
        ) -> [Line] {
            var lines = [Line]()

            for (index, section) in diffResult.sections.enumerated() {
                guard !section.isEmpty else { continue }

                if skipLastOnlyRemovalSection,
                   index == diffResult.sections.count - 1,
                   section.newSnippet.isEmpty
                {
                    continue
                }

                for (index, line) in section.oldSnippet.enumerated() {
                    if line.diff == .unchanged { continue }
                    let lineIndex = section.oldOffset + index
                    if lineIndex >= 0, lineIndex < originalHighlightedCode.count {
                        let oldLine = originalHighlightedCode[lineIndex]
                        lines.append(Line(index: lineIndex, kind: .deleted, string: oldLine))
                    }
                }

                for (index, line) in section.newSnippet.enumerated() {
                    let lineIndex = section.newOffset + index
                    guard lineIndex >= 0, lineIndex < highlightedCode.count else { continue }
                    if line.diff == .unchanged {
                        let newLine = highlightedCode[lineIndex]
                        lines.append(Line(index: lineIndex, kind: .unchanged, string: newLine))
                    } else {
                        let newLine = highlightedCode[lineIndex]
                        lines.append(Line(index: lineIndex, kind: .added, string: newLine))
                    }
                }
            }

            return lines
        }
    }

    @Perceptible
    class DiffStorage {
        private(set) var diffResult: CodeDiff.SnippetDiff?

        @PerceptionIgnored var originalCode: String?
        @PerceptionIgnored var code: String?
        @PerceptionIgnored private var diffTask: Task<Void, Error>?

        func diff(for view: AsyncDiffCodeBlock) {
            performDiff(for: view)
        }

        private func performDiff(for view: AsyncDiffCodeBlock) {
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
        private(set) var highlightedOriginalCode = [NSAttributedString]()
        private(set) var highlightedCode = [NSAttributedString]()
        private(set) var commonPrecedingSpaceCount = 0

        @PerceptionIgnored var code: String?
        @PerceptionIgnored var originalCode: String?
        @PerceptionIgnored private var foregroundColor: Color = .primary
        @PerceptionIgnored private var debounceFunction: DebounceFunction<AsyncDiffCodeBlock>?
        @PerceptionIgnored private var highlightTask: Task<Void, Error>?

        init() {
            debounceFunction = .init(duration: 0.1, block: { view in
                self.highlight(for: view)
            })
        }

        func highlight(debounce: Bool, for view: AsyncDiffCodeBlock) {
            if debounce {
                Task { @MainActor in await debounceFunction?(view) }
            } else {
                highlight(for: view)
            }
        }

        private func highlight(for view: AsyncDiffCodeBlock) {
            highlightTask?.cancel()
            let code = self.code ?? view.code
            let originalCode = self.originalCode ?? view.originalCode
            let language = view.language
            let scenario = view.scenario
            let brightMode = view.colorScheme != .dark
            let droppingLeadingSpaces = view.droppingLeadingSpaces
            let font = CodeHighlighting.SendableFont(font: view.font)
            foregroundColor = view.foregroundColor

            if highlightedCode.isEmpty {
                let content = CodeHighlighting.convertToCodeLines(
                    [.init(string: code), .init(string: originalCode ?? "")],
                    middleDotColor: brightMode
                        ? NSColor.black.withAlphaComponent(0.1)
                        : NSColor.white.withAlphaComponent(0.1),
                    droppingLeadingSpaces: droppingLeadingSpaces,
                    replaceSpacesWithMiddleDots: true
                )
                highlightedCode = content.code[0]
                highlightedOriginalCode = content.code[1]
                commonPrecedingSpaceCount = content.commonLeadingSpaceCount
            }

            highlightTask = Task {
                let result = await withUnsafeContinuation { continuation in
                    AsyncCodeBlock.queue.async {
                        let content = CodeHighlighting.highlighted(
                            code: [code, originalCode ?? ""],
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
                    self.highlightedCode = result.0[0]
                    self.highlightedOriginalCode = result.0[1]
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
    AsyncDiffCodeBlock(
        code: "    let foo = Bar()",
        originalCode: "    var foo // comment",
        language: "swift",
        startLineIndex: 10,
        scenario: "",
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        droppingLeadingSpaces: true,
        proposedForegroundColor: .primary
    )
    .frame(width: 400, height: 100)
}

#Preview("Multiple Line Suggestion") {
    AsyncDiffCodeBlock(
        code: "    let foo = Bar()\n    print(foo)\n    print(a)",
        originalCode: "    var foo // comment\n    print(bar)\n    print(a)",
        language: "swift",
        startLineIndex: 10,
        scenario: "",
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        droppingLeadingSpaces: true,
        proposedForegroundColor: .primary
    )
    .frame(width: 400, height: 100)
}

#Preview("Multiple Line Suggestion Including Whole Line Change in Diff") {
    AsyncDiffCodeBlock(
        code: "// comment\n    let foo = Bar()\n    print(bar)\n    print(foo)\n",
        originalCode: "    let foo = Bar()\n",
        language: "swift",
        startLineIndex: 10,
        scenario: "",
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        droppingLeadingSpaces: true,
        proposedForegroundColor: .primary
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
                AsyncDiffCodeBlock(
                    code: cases[index].code,
                    originalCode: cases[index].originalCode,
                    language: "swift",
                    startLineIndex: 10,
                    scenario: "",
                    font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                    droppingLeadingSpaces: true,
                    proposedForegroundColor: .primary
                )
            }
        }
    }

    return UpdateContent()
        .frame(width: 400, height: 200)
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
                ScrollView {
                    AsyncDiffCodeBlock(
                        code: newCode,
                        originalCode: originalCode,
                        language: "swift",
                        startLineIndex: 0,
                        scenario: "",
                        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
                        droppingLeadingSpaces: true,
                        proposedForegroundColor: .primary
                    )
                }
            }
            .padding()
            .frame(height: 600)
        }
    }
    
    return V()
}

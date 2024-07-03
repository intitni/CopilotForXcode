import DebounceFunction
import Foundation
import Perception
import SwiftUI

public struct AsyncCodeBlock: View {
    @Perceptible
    class Storage {
        static let queue = DispatchQueue(
            label: "code-block-highlight",
            qos: .userInteractive,
            attributes: .concurrent
        )

        var dimmedCharacterCount: Int = 0
        var code: String?
        private var highlightedCode = [NSAttributedString]()
        private var foregroundColor: Color = .primary
        private(set) var commonPrecedingSpaceCount = 0
        var highlightedContent: [NSAttributedString] {
            var highlightedCode = highlightedCode
            if dimmedCharacterCount > commonPrecedingSpaceCount,
               let firstLine = highlightedCode.first
            {
                let dimmedCount = dimmedCharacterCount - commonPrecedingSpaceCount
                let mutable = NSMutableAttributedString(attributedString: firstLine)
                let targetRange = NSRange(
                    location: 0,
                    length: min(firstLine.length, max(0, dimmedCount))
                )
                mutable.enumerateAttribute(
                    .foregroundColor,
                    in: NSRange(location: 0, length: firstLine.length)
                ) { value, range, _ in
                    guard let color = value as? NSColor else { return }
                    let opacity = max(0.1, color.alphaComponent * 0.4)
                    if targetRange.upperBound >= range.upperBound {
                        mutable.addAttribute(
                            .foregroundColor,
                            value: color.withAlphaComponent(opacity),
                            range: range
                        )
                    } else {
                        let intersection = NSIntersectionRange(targetRange, range)
                        guard !(intersection.length == 0) else { return }
                        let rangeA = intersection
                        mutable.addAttribute(
                            .foregroundColor,
                            value: color.withAlphaComponent(opacity),
                            range: rangeA
                        )

                        let rangeB = NSRange(
                            location: intersection.upperBound,
                            length: range.upperBound - intersection.upperBound
                        )
                        mutable.addAttribute(
                            .foregroundColor,
                            value: color,
                            range: rangeB
                        )
                    }
                }

                highlightedCode[0] = mutable
            }
            return highlightedCode
        }

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
            let font = view.font
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
                    Self.queue.async {
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

    @State var storage = Storage()
    @Environment(\.colorScheme) var colorScheme

    let code: String
    let language: String
    let startLineIndex: Int
    let scenario: String
    let font: NSFont
    let proposedForegroundColor: Color?
    let dimmedCharacterCount: Int
    let droppingLeadingSpaces: Bool

    public init(
        code: String,
        language: String,
        startLineIndex: Int,
        scenario: String,
        font: NSFont,
        droppingLeadingSpaces: Bool,
        proposedForegroundColor: Color?,
        dimmedCharacterCount: Int
    ) {
        self.code = code
        self.startLineIndex = startLineIndex
        self.language = language
        self.scenario = scenario
        self.font = font
        self.proposedForegroundColor = proposedForegroundColor
        self.dimmedCharacterCount = dimmedCharacterCount
        self.droppingLeadingSpaces = droppingLeadingSpaces
    }

    var foregroundColor: Color {
        proposedForegroundColor ?? (colorScheme == .dark ? .white : .black)
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 2) {
                let commonPrecedingSpaceCount = storage.commonPrecedingSpaceCount
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
            .padding([.trailing, .top, .bottom])
            .onAppear {
                storage.dimmedCharacterCount = dimmedCharacterCount
                storage.highlight(debounce: false, for: self)
            }
            .onChange(of: code) { code in
                storage.code = code // But why do we need this? Time to learn some SwiftUI!
                storage.highlight(debounce: true, for: self)
            }
            .onChange(of: colorScheme) { _ in
                storage.highlight(debounce: true, for: self)
            }
            .onChange(of: droppingLeadingSpaces) { _ in
                storage.highlight(debounce: true, for: self)
            }
            .onChange(of: scenario) { _ in
                storage.highlight(debounce: true, for: self)
            }
            .onChange(of: language) { _ in
                storage.highlight(debounce: true, for: self)
            }
            .onChange(of: proposedForegroundColor) { _ in
                storage.highlight(debounce: true, for: self)
            }
            .onChange(of: dimmedCharacterCount) { value in
                storage.dimmedCharacterCount = value
            }
        }
    }

    static func highlight(
        code: String,
        language: String,
        scenario: String,
        colorScheme: ColorScheme,
        font: NSFont,
        droppingLeadingSpaces: Bool
    ) -> (code: [NSAttributedString], commonLeadingSpaceCount: Int) {
        return CodeHighlighting.highlighted(
            code: code,
            language: language,
            scenario: scenario,
            brightMode: colorScheme != .dark,
            droppingLeadingSpaces: droppingLeadingSpaces,
            font: font
        )
    }
}


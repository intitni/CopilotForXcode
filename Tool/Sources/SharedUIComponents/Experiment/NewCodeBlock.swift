import STTextView
import SwiftUI

private let insetBottom = 12 as Double
private let insetTop = 12 as Double

/// This SwiftUI view can be used to view and edit rich text.
struct _CodeBlock: View {
    @Binding private var selection: NSRange?
    @State private var contentHeight: Double = 500
    let fontSize: Double
    let commonPrecedingSpaceCount: Int
    let highlightedCode: AttributedString
    let colorScheme: ColorScheme
    let droppingLeadingSpaces: Bool

    /// Create a text edit view with a certain text that uses a certain options.
    /// - Parameters:
    ///   - text: The attributed string content
    ///   - options: Editor options
    ///   - plugins: Editor plugins
    public init(
        code: String,
        language: String,
        firstLinePrecedingSpaceCount: Int,
        colorScheme: ColorScheme,
        fontSize: Double,
        droppingLeadingSpaces: Bool,
        selection: Binding<NSRange?> = .constant(nil)
    ) {
        _selection = selection
        self.fontSize = fontSize
        self.colorScheme = colorScheme
        self.droppingLeadingSpaces = droppingLeadingSpaces

        let padding = firstLinePrecedingSpaceCount > 0
            ? String(repeating: " ", count: firstLinePrecedingSpaceCount)
            : ""
        let result = Self.highlight(
            code: padding + code,
            language: language,
            colorScheme: colorScheme,
            fontSize: fontSize,
            droppingLeadingSpaces: droppingLeadingSpaces
        )
        commonPrecedingSpaceCount = result.commonLeadingSpaceCount
        highlightedCode = result.code
    }

    public var body: some View {
        _CodeBlockRepresentable(
            text: highlightedCode,
            selection: $selection,
            fontSize: fontSize,
            onHeightChange: { height in
                print("Q", height)
                contentHeight = height
            }
        )
        .frame(height: contentHeight, alignment: .topLeading)
        .background(.background)
        .colorScheme(colorScheme)
        .onAppear {
            print("")
        }
    }

    static func highlight(
        code: String,
        language: String,
        colorScheme: ColorScheme,
        fontSize: Double,
        droppingLeadingSpaces: Bool
    ) -> (code: AttributedString, commonLeadingSpaceCount: Int) {
        let (lines, commonLeadingSpaceCount) = highlighted(
            code: code,
            language: language,
            brightMode: colorScheme != .dark,
            droppingLeadingSpaces: droppingLeadingSpaces,
            fontSize: fontSize,
            replaceSpacesWithMiddleDots: false
        )

        let string = NSMutableAttributedString()
        for (index, line) in lines.enumerated() {
            string.append(line)
            if index < lines.count - 1 {
                string.append(NSAttributedString(string: "\n"))
            }
        }

        return (code: .init(string), commonLeadingSpaceCount: commonLeadingSpaceCount)
    }
}

private struct _CodeBlockRepresentable: NSViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.lineSpacing) private var lineSpacing

    @Binding private var selection: NSRange?
    let text: AttributedString
    let fontSize: Double
    let onHeightChange: (Double) -> Void

    init(
        text: AttributedString,
        selection: Binding<NSRange?>,
        fontSize: Double,
        onHeightChange: @escaping (Double) -> Void
    ) {
        self.text = text
        _selection = selection
        self.fontSize = fontSize
        self.onHeightChange = onHeightChange
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = STTextViewFrameObservable.scrollableTextView()
        scrollView.contentInsets = .init(top: 0, left: 0, bottom: insetBottom, right: 0)
        scrollView.automaticallyAdjustsContentInsets = false
        let textView = scrollView.documentView as! STTextView
        textView.delegate = context.coordinator
        textView.highlightSelectedLine = false
        textView.widthTracksTextView = true
        textView.heightTracksTextView = true
        textView.isEditable = true

        textView.setSelectedRange(NSRange())
        let lineNumberRuler = STLineNumberRulerView(textView: textView)
        lineNumberRuler.backgroundColor = .clear
        lineNumberRuler.separatorColor = .clear
        lineNumberRuler.rulerInsets = .init(leading: 10, trailing: 10)
        scrollView.verticalRulerView = lineNumberRuler
        let columnNumberRuler = ColumnRuler(textView: textView)
        scrollView.horizontalRulerView = columnNumberRuler
        scrollView.rulersVisible = true

        context.coordinator.isUpdating = true
        textView.setAttributedString(NSAttributedString(text))
        context.coordinator.isUpdating = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self

        let textView = scrollView.documentView as! STTextViewFrameObservable

        textView.onHeightChange = onHeightChange
        textView.showsInvisibleCharacters = true
        textView.textContainer.lineBreakMode = .byCharWrapping

        if let columnNumberRuler = scrollView.horizontalRulerView as? ColumnRuler {
            columnNumberRuler.columnNumber = 5
        }

        do {
            context.coordinator.isUpdating = true
            if context.coordinator.isDidChangeText == false {
                textView.setAttributedString(.init(text))
            }
            context.coordinator.isUpdating = false
            context.coordinator.isDidChangeText = false
        }

        if textView.selectedRange() != selection, let selection {
            textView.setSelectedRange(selection)
        }

        if textView.isSelectable != isEnabled {
            textView.isSelectable = isEnabled
        }

        textView.isEditable = false

        if !textView.widthTracksTextView {
            textView.widthTracksTextView = false
        }

        if !textView.heightTracksTextView {
            textView.heightTracksTextView = true
        }

        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if textView.font != font {
            textView.font = font
        }
    }

    func makeCoordinator() -> TextCoordinator {
        TextCoordinator(parent: self)
    }

    private func styledAttributedString(_ typingAttributes: [NSAttributedString.Key: Any])
        -> AttributedString
    {
        let paragraph = (typingAttributes[.paragraphStyle] as! NSParagraphStyle)
            .mutableCopy() as! NSMutableParagraphStyle
        if paragraph.lineSpacing != lineSpacing {
            paragraph.lineSpacing = lineSpacing
            var typingAttributes = typingAttributes
            typingAttributes[.paragraphStyle] = paragraph

            let attributeContainer = AttributeContainer(typingAttributes)
            var styledText = text
            styledText.mergeAttributes(attributeContainer, mergePolicy: .keepNew)
            return styledText
        }

        return text
    }

    class TextCoordinator: STTextViewDelegate {
        var parent: _CodeBlockRepresentable
        var isUpdating: Bool = false
        var isDidChangeText: Bool = false
        var enqueuedValue: AttributedString?

        init(parent: _CodeBlockRepresentable) {
            self.parent = parent
        }

        func textViewDidChangeText(_ notification: Notification) {
            guard let textView = notification.object as? STTextView else {
                return
            }

            (textView as! STTextViewFrameObservable).recalculateSize()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? STTextView else {
                return
            }

            Task { @MainActor in
                self.parent.selection = textView.selectedRange()
            }
        }
    }
}

private class STTextViewFrameObservable: STTextView {
    var onHeightChange: ((Double) -> Void)?
    func recalculateSize() {
        var maxY = 0 as Double
        textLayoutManager.enumerateTextLayoutFragments(
            in: textLayoutManager.documentRange,
            options: [.ensuresLayout]
        ) { fragment in
            print(fragment.layoutFragmentFrame)
            maxY = max(maxY, fragment.layoutFragmentFrame.maxY)
            return true
        }
        onHeightChange?(maxY)
    }
}

private final class ColumnRuler: NSRulerView {
    var columnNumber: Int = 0

    private var textView: STTextView? {
        clientView as? STTextView
    }

    public required init(textView: STTextView, scrollView: NSScrollView? = nil) {
        super.init(
            scrollView: scrollView ?? textView.enclosingScrollView,
            orientation: .verticalRuler
        )
        clientView = textView
        ruleThickness = insetBottom
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_: NSRect) {
        guard let context: CGContext = NSGraphicsContext.current?.cgContext else { return }
        NSColor.windowBackgroundColor.withAlphaComponent(0.6).setFill()
        context.fill(bounds)

        let insetLeft = scrollView?.verticalRulerView?.bounds.width ?? 0
        var drawingBounds = bounds
        drawingBounds.origin.x += insetLeft + 4
        let fontSize = 10 as Double
        drawingBounds.origin.y = (insetTop - fontSize) / 2
        NSString(string: "\(columnNumber)").draw(in: drawingBounds, withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ])
    }
}


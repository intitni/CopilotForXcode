import SwiftUI

public struct AutoresizingCustomTextEditor: View {
    @Binding public var text: String
    public let font: NSFont
    public let isEditable: Bool
    public let maxHeight: Double
    public let onSubmit: () -> Void
    public var completions: (_ text: String, _ words: [String], _ range: NSRange) -> [String]

    public init(
        text: Binding<String>,
        font: NSFont,
        isEditable: Bool,
        maxHeight: Double,
        onSubmit: @escaping () -> Void,
        completions: @escaping (_ text: String, _ words: [String], _ range: NSRange)
            -> [String] = { _, _, _ in [] }
    ) {
        _text = text
        self.font = font
        self.isEditable = isEditable
        self.maxHeight = maxHeight
        self.onSubmit = onSubmit
        self.completions = completions
    }

    public var body: some View {
        ZStack(alignment: .center) {
            // a hack to support dynamic height of TextEditor
            Text(text.isEmpty ? "Hi" : text).opacity(0)
                .font(.init(font))
                .frame(maxWidth: .infinity, maxHeight: maxHeight)
                .padding(.top, 1)
                .padding(.bottom, 2)
                .padding(.horizontal, 4)

            CustomTextEditor(
                text: $text,
                font: font,
                onSubmit: onSubmit,
                completions: completions
            )
            .padding(.top, 1)
            .padding(.bottom, -1)
        }
    }
}

public struct CustomTextEditor: NSViewRepresentable {
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @Binding public var text: String
    public let font: NSFont
    public let isEditable: Bool
    public let onSubmit: () -> Void
    public var completions: (_ text: String, _ words: [String], _ range: NSRange) -> [String]

    public init(
        text: Binding<String>,
        font: NSFont,
        isEditable: Bool = true,
        onSubmit: @escaping () -> Void,
        completions: @escaping (_ text: String, _ words: [String], _ range: NSRange)
            -> [String] = { _, _, _ in [] }
    ) {
        _text = text
        self.font = font
        self.isEditable = isEditable
        self.onSubmit = onSubmit
        self.completions = completions
    }

    public func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.completions = completions
        let textView = (context.coordinator.theTextView.documentView as! NSTextView)
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        return context.coordinator.theTextView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.completions = completions
        let textView = (context.coordinator.theTextView.documentView as! NSTextView)
        textView.isEditable = isEditable
        guard textView.string != text else { return }
        textView.string = text
        textView.undoManager?.removeAllActions()
    }
}

public extension CustomTextEditor {
    class Coordinator: NSObject, NSTextViewDelegate {
        var view: CustomTextEditor
        var theTextView = NSTextView.scrollableTextView()
        var affectedCharRange: NSRange?
        var completions: (String, [String], _ range: NSRange) -> [String] = { _, _, _ in [] }

        init(_ view: CustomTextEditor) {
            self.view = view
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            view.text = textView.string
            textView.complete(nil)
        }

        public func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSTextView.insertNewline(_:)) {
                if let event = NSApplication.shared.currentEvent,
                   !event.modifierFlags.contains(.shift),
                   event.keyCode == 36 // enter
                {
                    view.onSubmit()
                    return true
                }
            }

            return false
        }

        public func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            return true
        }

        public func textView(
            _ textView: NSTextView,
            completions words: [String],
            forPartialWordRange charRange: NSRange,
            indexOfSelectedItem index: UnsafeMutablePointer<Int>?
        ) -> [String] {
            index?.pointee = -1
            return completions(textView.textStorage?.string ?? "", words, charRange)
        }
    }
}


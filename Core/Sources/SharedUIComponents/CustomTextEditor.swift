import SwiftUI

public struct CustomTextEditor: NSViewRepresentable {
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @Binding public var text: String
    public let font: NSFont
    public let onSubmit: () -> Void
    public var completions: (_ text: String, _ words: [String], _ range: NSRange) -> [String]

    public init(
        text: Binding<String>,
        font: NSFont,
        onSubmit: @escaping () -> Void,
        completions: @escaping (_ text: String, _ words: [String], _ range: NSRange)
            -> [String] = { _, _, _ in [] }
    ) {
        _text = text
        self.font = font
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

        return context.coordinator.theTextView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.completions = completions
        let textView = (context.coordinator.theTextView.documentView as! NSTextView)
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


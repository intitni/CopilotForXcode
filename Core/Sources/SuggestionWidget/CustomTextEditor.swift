import SwiftUI

struct CustomTextEditor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @Binding var text: String
    let font: NSFont
    let onSubmit: () -> Void
    var completions: (_ text: String, _ words: [String], _ range: NSRange)
        -> [String] = { _, _, _ in
            []
        }

    func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.completions = completions
        let textView = (context.coordinator.theTextView.documentView as! NSTextView)
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.allowsUndo = true
        textView.drawsBackground = false

        return context.coordinator.theTextView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.completions = completions
        let textView = (context.coordinator.theTextView.documentView as! NSTextView)
        guard textView.string != text else { return }
        textView.string = text
        textView.undoManager?.removeAllActions()
    }
}

extension CustomTextEditor {
    class Coordinator: NSObject, NSTextViewDelegate {
        var view: CustomTextEditor
        var theTextView = NSTextView.scrollableTextView()
        var affectedCharRange: NSRange?
        var completions: (String, [String], _ range: NSRange) -> [String] = { _, _, _ in [] }

        init(_ view: CustomTextEditor) {
            self.view = view
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            view.text = textView.string
            textView.complete(nil)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
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

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            return true
        }

        func textView(
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


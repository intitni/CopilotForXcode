import AppKit
import Foundation
import Preferences
import SwiftUI

public struct FontPicker<Label: View>: View {
    @State var fontManagerDelegate: FontManagerDelegate?
    @Binding var font: NSFont
    let label: Label

    public init(font: Binding<NSFont>, @ViewBuilder label: () -> Label) {
        _font = font
        self.label = label()
    }

    public var body: some View {
        if #available(macOS 13.0, *) {
            LabeledContent {
                button
            } label: {
                label
            }
        } else {
            HStack {
                label
                button
            }
        }
    }
    
    var button: some View {
        Button {
            if NSFontPanel.shared.isVisible {
                NSFontPanel.shared.orderOut(nil)
            }

            self.fontManagerDelegate = FontManagerDelegate(font: font) {
                self.font = $0
            }
            NSFontManager.shared.target = self.fontManagerDelegate
            NSFontPanel.shared.setPanelFont(self.font, isMultiple: false)
            NSFontPanel.shared.orderBack(nil)
        } label: {
            HStack {
                Text(font.fontName)
                    + Text(" - ")
                    + Text(font.pointSize, format: .number.precision(.fractionLength(1)))
                    + Text("pt")

                Spacer().frame(width: 30)

                Image(systemName: "textformat")
                    .frame(width: 13)
                    .scaledToFit()
            }
        }
    }

    final class FontManagerDelegate: NSObject {
        let font: NSFont
        let onSelection: (NSFont) -> Void
        init(font: NSFont, onSelection: @escaping (NSFont) -> Void) {
            self.font = font
            self.onSelection = onSelection
        }

        @objc func changeFont(_ sender: NSFontManager) {
            onSelection(sender.convert(font))
        }
    }
}

public extension FontPicker {
    init(font: Binding<UserDefaultsStorageBox<StorableFont>>, @ViewBuilder label: () -> Label) {
        _font = Binding(
            get: { font.wrappedValue.value.nsFont },
            set: { font.wrappedValue = .init(StorableFont(nsFont: $0)) }
        )
        self.label = label()
    }
}

#Preview {
    FontPicker(font: .constant(.systemFont(ofSize: 15))) {
        Text("Font")
    }
    .padding()
}


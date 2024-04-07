import AppKit
import Foundation
import Preferences
import SwiftUI

public struct FontPicker: View {
    @Binding var font: NSFont
    @State var fontManagerDelegate: FontManagerDelegate?

    public init(font: Binding<NSFont>) {
        _font = font
    }

    public var body: some View {
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
    init(font: Binding<StorableFont>) {
        _font = Binding(
            get: { font.wrappedValue.nsFont },
            set: { font.wrappedValue = StorableFont(nsFont: $0) }
        )
    }
}

#Preview {
    FontPicker(font: .constant(.systemFont(ofSize: 15)))
        .padding()
}


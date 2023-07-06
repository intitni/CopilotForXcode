import Foundation
import SwiftUI

// Hack to disable smart quotes and dashes in TextEditor
extension NSTextView {
    open override var frame: CGRect {
        didSet {
            self.isAutomaticQuoteSubstitutionEnabled = false
            self.isAutomaticDashSubstitutionEnabled = false
        }
    }
}

struct EditableText: View {
    var text: Binding<String>
    @State var isEditing: Bool = false

    var body: some View {
        Button(action: {
            isEditing = true
        }) {
            HStack(alignment: .top) {
                Text(text.wrappedValue)
                    .font(Font.system(.body, design: .monospaced))
                    .padding(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .textBackgroundColor))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(nsColor: .separatorColor), style: .init(lineWidth: 1))
                    }
                Image(systemName: "square.and.pencil")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14)
                    .padding(4)
                    .background(
                        Color.primary.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 4)
                    )
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isEditing) {
            VStack {
                TextEditor(text: text)
                    .font(Font.system(.body, design: .monospaced))
                    .padding(4)
                    .frame(minHeight: 120)
                    .multilineTextAlignment(.leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                Button(action: {
                    isEditing = false
                }) {
                    Text("Done")
                }
            }
            .padding()
            .frame(width: 600, height: 500)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}


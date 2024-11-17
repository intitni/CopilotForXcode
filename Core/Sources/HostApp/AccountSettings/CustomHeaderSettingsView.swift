import AIModel
import Foundation
import SwiftUI

struct CustomHeaderSettingsView: View {
    @Binding var headers: [ChatModel.Info.CustomHeaderInfo.HeaderField]
    @Environment(\.dismiss) var dismiss
    @State private var newKey = ""
    @State private var newValue = ""

    var body: some View {
        VStack {
            List {
                ForEach(headers.indices, id: \.self) { index in
                    HStack {
                        TextField("Key", text: Binding(
                            get: { headers[index].key },
                            set: { newKey in
                                headers[index].key = newKey
                            }
                        ))
                        TextField("Value", text: Binding(
                            get: { headers[index].value },
                            set: { headers[index].value = $0 }
                        ))
                        Button(action: {
                            headers.remove(at: index)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }

                HStack {
                    TextField("New Key", text: $newKey)
                    TextField("New Value", text: $newValue)
                    Button(action: {
                        if !newKey.isEmpty {
                            headers.append(ChatModel.Info.CustomHeaderInfo.HeaderField(
                                key: newKey,
                                value: newValue
                            ))
                            newKey = ""
                            newValue = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }.padding()
        }
        .frame(height: 500)
    }
}

#Preview {
    struct V: View {
        @State var headers: [ChatModel.Info.CustomHeaderInfo.HeaderField] = [
            .init(key: "key", value: "value"),
            .init(key: "key2", value: "value2"),
        ]
        var body: some View {
            CustomHeaderSettingsView(headers: $headers)
        }
    }

    return V()
}


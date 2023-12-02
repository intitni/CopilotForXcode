import SwiftUI

struct SubSection<Title: View, Content: View>: View {
    let title: Title
    let description: String
    @ViewBuilder let content: () -> Content

    init(title: Title, description: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.description = description
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading) {
            if !(title is EmptyView && description.isEmpty) {
                VStack(alignment: .leading, spacing: 8) {
                    title
                        .font(.system(size: 14).weight(.semibold))

                    if !description.isEmpty {
                        Text(description)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !(title is EmptyView && description.isEmpty) {
                Divider().padding(.bottom, 4)
            }

            content()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.2))
        }
    }
}

extension SubSection where Title == EmptyView {
    init(description: String = "", @ViewBuilder content: @escaping () -> Content) {
        self.init(title: EmptyView(), description: description, content: content)
    }
}

#Preview("Sub Section Default Style") {
    SubSection(title: Text("Title"), description: "Description") {
        Toggle(isOn: .constant(true), label: {
            Text("Label")
        })

        Toggle(isOn: .constant(true), label: {
            Text("Label")
        })

        Picker("Label", selection: .constant(0)) {
            Text("Label").tag(0)
            Text("Label").tag(1)
            Text("Label").tag(2)
        }
    }
    .padding()
}

#Preview("Sub Section No Title") {
    SubSection(description: "Description") {
        Toggle(isOn: .constant(true), label: {
            Text("Label")
        })

        Toggle(isOn: .constant(true), label: {
            Text("Label")
        })

        Picker("Label", selection: .constant(0)) {
            Text("Label").tag(0)
            Text("Label").tag(1)
            Text("Label").tag(2)
        }
    }
    .padding()
}

#Preview("Sub Section No Title or Description") {
    SubSection {
        Toggle(isOn: .constant(true), label: {
            Text("Label")
        })

        Toggle(isOn: .constant(true), label: {
            Text("Label")
        })

        Picker("Label", selection: .constant(0)) {
            Text("Label").tag(0)
            Text("Label").tag(1)
            Text("Label").tag(2)
        }
    }
    .padding()
}


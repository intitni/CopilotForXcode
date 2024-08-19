import SwiftUI

public struct SubSection<Title: View, Description: View, Content: View>: View {
    public let title: Title
    public let description: Description
    @ViewBuilder public let content: () -> Content

    public init(title: Title, description: Description, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.description = description
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading) {
            if !(title is EmptyView && description is EmptyView) {
                VStack(alignment: .leading, spacing: 8) {
                    title
                        .font(.system(size: 14).weight(.semibold))

                    description
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !(title is EmptyView && description is EmptyView) {
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

public extension SubSection where Description == Text {
    init(title: Title, description: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, description: Text(description), content: content)
    }
}

public extension SubSection where Description == EmptyView {
    init(title: Title, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, description: EmptyView(), content: content)
    }
}

public extension SubSection where Title == EmptyView {
    init(description: Description, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: EmptyView(), description: description, content: content)
    }
}

public extension SubSection where Title == EmptyView, Description == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.init(title: EmptyView(), description: EmptyView(), content: content)
    }
}

public extension SubSection where Title == EmptyView, Description == Text {
    init(description: String, @ViewBuilder content: @escaping () -> Content) {
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


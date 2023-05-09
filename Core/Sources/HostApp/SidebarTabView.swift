import SwiftUI

private struct SidebarItem: Identifiable, Equatable {
    var id: Int { tag }
    var tag: Int
    var title: String
    var subtitle: String? = nil
    var image: String? = nil
}

private struct SidebarItemPreferenceKey: PreferenceKey {
    static var defaultValue: [SidebarItem] = []
    static func reduce(value: inout [SidebarItem], nextValue: () -> [SidebarItem]) {
        value.append(contentsOf: nextValue())
    }
}

private struct SidebarTabTagKey: EnvironmentKey {
    static var defaultValue: Int = 0
}

private extension EnvironmentValues {
    var sidebarTabTag: Int {
        get { self[SidebarTabTagKey.self] }
        set { self[SidebarTabTagKey.self] = newValue }
    }
}

private struct SidebarTabViewWrapper<Content: View>: View {
    @Environment(\.sidebarTabTag) var sidebarTabTag
    var tag: Int
    var title: String
    var subtitle: String? = nil
    var image: String? = nil
    var content: () -> Content

    var body: some View {
        Group {
            if tag == sidebarTabTag {
                content()
            } else {
                Color.clear
            }
        }
        .preference(
            key: SidebarItemPreferenceKey.self,
            value: [.init(tag: tag, title: title, subtitle: subtitle, image: image)]
        )
    }
}

extension View {
    func sidebarItem(
        tag: Int,
        title: String,
        subtitle: String? = nil,
        image: String? = nil
    ) -> some View {
        SidebarTabViewWrapper(
            tag: tag,
            title: title,
            subtitle: subtitle,
            image: image,
            content: { self }
        )
    }
}

struct SidebarTabView<Content: View>: View {
    @State private var sidebarItems = [SidebarItem]()
    @Binding var tag: Int
    @ViewBuilder var views: () -> Content
    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(sidebarItems) { item in
                        Button(action: {
                            tag = item.tag
                        }) {
                            HStack {
                                if let image = item.image {
                                    Image(systemName: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .foregroundStyle(.primary)
                                    if let subtitle = item.subtitle {
                                        Text(subtitle)
                                            .lineSpacing(0)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .opacity(0.5)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Color.primary.opacity(tag == item.tag ? 0.1 : 0),
                                in: RoundedRectangle(cornerRadius: 4)
                            )
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 200)
                .padding(.vertical, 8)
            }
            .background(Color.primary.opacity(0.05))

            Divider()

            ZStack(alignment: .topLeading) {
                views()
            }
        }
        .environment(\.sidebarTabTag, tag)
        .onPreferenceChange(SidebarItemPreferenceKey.self) { items in
            sidebarItems = items
        }
    }
}

struct SidebarTabView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarTabView(tag: .constant(0)) {
            Color.red.sidebarItem(
                tag: 0,
                title: "Hello",
                subtitle: "Meow\nMeow",
                image: "person.circle.fill"
            )
            Color.blue.sidebarItem(
                tag: 1,
                title: "World",
                image: "person.circle.fill"
            )
            Color.blue.sidebarItem(
                tag: 3,
                title: "Pikachu",
                image: "person.circle.fill"
            )
        }
    }
}


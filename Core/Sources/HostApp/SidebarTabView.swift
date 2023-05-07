import SwiftUI

struct SidebarItem: Identifiable, Equatable {
    var id: Int { tag }
    var tag: Int
    var title: String
    var subtitle: String? = nil
    var image: String? = nil
}

struct SidebarItemPreferenceKey: PreferenceKey {
    static var defaultValue: [SidebarItem] = []
    static func reduce(value: inout [SidebarItem], nextValue: () -> [SidebarItem]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    func sidebarItem(
        tag: Int,
        currentTag: Int,
        title: String,
        subtitle: String? = nil,
        image: String? = nil
    ) -> some View {
        return opacity(tag != currentTag ? 0 : 1)
            .background(GeometryReader { _ in
                Color.clear.preference(
                    key: SidebarItemPreferenceKey.self,
                    value: [.init(tag: tag, title: title, subtitle: subtitle, image: image)]
                )
            })
    }
}

struct SidebarTabView<Content: View>: View {
    @State var sidebarItems = [SidebarItem]()
    @Binding var tag: Int
    @ViewBuilder var views: (_ tag: Int) -> Content
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
                                        .frame(height: 20)
                                }
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                        .foregroundStyle(.primary)
                                    if let subtitle = item.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .opacity(0.5)
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
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .frame(width: 200)
                .padding(.vertical, 8)
            }
            .background(Color.primary.opacity(0.05))
            
            Divider()

            ZStack(alignment: .topLeading) {
                views(tag)
            }
        }
        .onPreferenceChange(SidebarItemPreferenceKey.self) { items in
            sidebarItems = items
        }
    }
}

struct SidebarTabView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarTabView(tag: .constant(0)) { tag in
            Color.red.sidebarItem(
                tag: 0,
                currentTag: tag,
                title: "Hello",
                subtitle: "Meow",
                image: "person.circle.fill"
            )
            Color.blue.sidebarItem(
                tag: 1,
                currentTag: tag,
                title: "World",
                image: "person.circle.fill"
            )
            Color.blue.sidebarItem(
                tag: 3,
                currentTag: tag,
                title: "Pikachu",
                image: "person.circle.fill"
            )
        }
    }
}


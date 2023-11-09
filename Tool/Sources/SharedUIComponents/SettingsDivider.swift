import SwiftUI

public struct SettingsDivider<Title: View>: View {
    let title: Title?
    
    public init(_ title: Title) {
        self.title = title
    }
    
    public var body: some View {
        if let title {
            HStack {
                VStack {
                    Divider()
                }
                title
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .zIndex(2)
                VStack {
                    Divider()
                }
            }
            .padding(.vertical, 8)
        } else {
            Divider()
                .padding(.vertical, 8)
        }
    }
}

extension SettingsDivider where Title == Text {
    public init(_ title: String) {
        self.title = Text(title)
    }
}

extension SettingsDivider where Title == EmptyView {
    public init() {
        self.title = nil
    }
}

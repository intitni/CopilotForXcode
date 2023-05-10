import Foundation
import SwiftUI
import UpdateChecker

enum Tab: Int, CaseIterable, Equatable {
    case general
    case service
    case feature
    case customCommand
    case debug
}

public struct TabContainer: View {
    @StateObject var toastController = ToastController(messages: [])
    @State var tab = Tab.general

    public init() {}

    init(toastController: ToastController) {
        _toastController = StateObject(wrappedValue: toastController)
    }

    public var body: some View {
        VStack(spacing: 0) {
            TabBar(tab: $tab)
                .padding(.bottom, 8)

            Divider()

            Group {
                switch tab {
                case .general:
                    GeneralView()
                case .service:
                    ServiceView()
                case .feature:
                    FeatureSettingsView()
                case .customCommand:
                    CustomCommandView()
                case .debug:
                    DebugSettingsView()
                }
            }
            .frame(minHeight: 400)
            .overlay(alignment: .bottom) {
                VStack(spacing: 4) {
                    ForEach(toastController.messages) { message in
                        message.content
                            .foregroundColor(.white)
                            .padding(8)
                            .background({
                                switch message.type {
                                case .info: return Color(nsColor: .systemIndigo)
                                case .error: return Color(nsColor: .systemRed)
                                case .warning: return Color(nsColor: .systemOrange)
                                }
                            }() as Color, in: RoundedRectangle(cornerRadius: 8))
                            .shadow(color: Color.black.opacity(0.2), radius: 4)
                    }
                }
                .padding()
                .allowsHitTesting(false)
            }
        }
        .focusable(false)
        .padding(.top, 8)
        .environment(\.toast) { [toastController] content, type in
            toastController.toast(content: content, type: type)
        }
    }
}

struct TabBar: View {
    @Binding var tab: Tab

    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                switch tab {
                case .general:
                    TabBarButton(
                        currentTab: $tab,
                        title: "General",
                        image: "app.gift",
                        tab: tab
                    )
                case .service:
                    TabBarButton(currentTab: $tab, title: "Service", image: "globe", tab: tab)
                case .feature:
                    TabBarButton(
                        currentTab: $tab,
                        title: "Feature",
                        image: "star.square.on.square",
                        tab: tab
                    )
                case .customCommand:
                    TabBarButton(
                        currentTab: $tab,
                        title: "Custom Command",
                        image: "command.square",
                        tab: tab
                    )
                case .debug:
                    TabBarButton(
                        currentTab: $tab,
                        title: "Advanced",
                        image: "gearshape.2",
                        tab: tab
                    )
                }
            }
        }
    }
}

struct TabBarButton: View {
    @Binding var currentTab: Tab
    @State var isHovered = false
    var title: String
    var image: String
    var tab: Tab

    var body: some View {
        Button(action: {
            self.currentTab = tab
        }) {
            VStack(spacing: 2) {
                Image(systemName: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
                Text(title)
            }
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .padding(.top, 4)
            .background(
                tab == currentTab
                    ? Color(nsColor: .textColor).opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .background(
                isHovered
                    ? Color(nsColor: .textColor).opacity(0.05)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .onHover(perform: { yes in
            isHovered = yes
        })
        .buttonStyle(.borderless)
    }
}

// MARK: - Environment Keys

struct UpdateCheckerKey: EnvironmentKey {
    static var defaultValue: UpdateChecker = .init(hostBundle: nil)
}

public extension EnvironmentValues {
    var updateChecker: UpdateChecker {
        get { self[UpdateCheckerKey.self] }
        set { self[UpdateCheckerKey.self] = newValue }
    }
}

enum ToastType {
    case info
    case warning
    case error
}

struct ToastKey: EnvironmentKey {
    static var defaultValue: (Text, ToastType) -> Void = { _, _ in }
}

extension EnvironmentValues {
    var toast: (Text, ToastType) -> Void {
        get { self[ToastKey.self] }
        set { self[ToastKey.self] = newValue }
    }
}

@MainActor
class ToastController: ObservableObject {
    struct Message: Identifiable {
        var id: UUID
        var type: ToastType
        var content: Text
    }

    @Published var messages: [Message] = []

    init(messages: [Message]) {
        self.messages = messages
    }

    func toast(content: Text, type: ToastType) {
        let id = UUID()
        let message = Message(id: id, type: type, content: content)

        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.2)) {
                messages.append(message)
                messages = messages.suffix(3)
            }
            try await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation(.easeInOut(duration: 0.2)) {
                messages.removeAll { $0.id == id }
            }
        }
    }
}

// MARK: - Previews

struct TabContainer_Previews: PreviewProvider {
    static var previews: some View {
        TabContainer()
            .frame(width: 800)
    }
}

struct TabContainer_Toasts_Previews: PreviewProvider {
    static var previews: some View {
        TabContainer(toastController: .init(messages: [
            .init(id: UUID(), type: .info, content: Text("info")),
            .init(id: UUID(), type: .error, content: Text("error")),
            .init(id: UUID(), type: .warning, content: Text("warning")),
        ]))
        .frame(width: 800)
    }
}


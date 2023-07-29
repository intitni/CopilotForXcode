import Foundation
import SwiftUI

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

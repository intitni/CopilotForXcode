import Foundation
import SwiftUI
import Dependencies

public enum ToastType {
    case info
    case warning
    case error
}

public struct ToastKey: EnvironmentKey {
    public static var defaultValue: (String, ToastType) -> Void = { _, _ in }
}

public extension EnvironmentValues {
    var toast: (String, ToastType) -> Void {
        get { self[ToastKey.self] }
        set { self[ToastKey.self] = newValue }
    }
}

public struct ToastControllerDependencyKey: DependencyKey {
    public static let liveValue = ToastController(messages: [])
}

public extension DependencyValues {
    var toastController: ToastController {
        get { self[ToastControllerDependencyKey.self] }
        set { self[ToastControllerDependencyKey.self] = newValue }
    }
    
    var toast: (String, ToastType) -> Void {
        get { toastController.toast }
    }
}

public class ToastController: ObservableObject {
    public struct Message: Identifiable {
        public var id: UUID
        public var type: ToastType
        public var content: Text
        public init(id: UUID, type: ToastType, content: Text) {
            self.id = id
            self.type = type
            self.content = content
        }
    }

    @Published public var messages: [Message] = []

    public init(messages: [Message]) {
        self.messages = messages
    }

    public func toast(content: String, type: ToastType) {
        let id = UUID()
        let message = Message(id: id, type: type, content: Text(content))

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


import ComposableArchitecture
import Dependencies
import Foundation
import SwiftUI

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
        return { content, type in
            toastController.toast(content: content, type: type, namespace: nil)
        }
    }

    var namespacedToast: (String, ToastType, String) -> Void {
        return {
            content, type, namespace in
            toastController.toast(content: content, type: type, namespace: namespace)
        }
    }
}

public class ToastController: ObservableObject {
    public struct Message: Identifiable, Equatable {
        public var namespace: String?
        public var id: UUID
        public var type: ToastType
        public var content: Text
        public init(id: UUID, type: ToastType, namespace: String? = nil, content: Text) {
            self.namespace = namespace
            self.id = id
            self.type = type
            self.content = content
        }
    }

    @Published public var messages: [Message] = []

    public init(messages: [Message]) {
        self.messages = messages
    }

    public func toast(content: String, type: ToastType, namespace: String? = nil) {
        let id = UUID()
        let message = Message(id: id, type: type, namespace: namespace, content: Text(content))

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

public struct Toast: ReducerProtocol {
    public typealias Message = ToastController.Message
    public struct State: Equatable {
        var isObservingToastController = false
        public var messages: [Message] = []

        public init(messages: [Message] = []) {
            self.messages = messages
        }
    }

    public enum Action: Equatable {
        case start
        case updateMessages([Message])
        case toast(String, ToastType, String?)
    }

    @Dependency(\.toastController) var toastController

    struct CancelID: Hashable {}

    public init() {}

    public var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .start:
                guard !state.isObservingToastController else { return .none }
                state.isObservingToastController = true
                return .run { send in
                    let stream = AsyncStream<[Message]> { continuation in
                        let cancellable = toastController.$messages.sink { newValue in
                            continuation.yield(newValue)
                        }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await newValue in stream {
                        try Task.checkCancellation()
                        await send(.updateMessages(newValue), animation: .linear(duration: 0.2))
                    }
                }.cancellable(id: CancelID(), cancelInFlight: true)
            case let .updateMessages(messages):
                state.messages = messages
                return .none
            case let .toast(content, type, namespace):
                toastController.toast(content: content, type: type, namespace: namespace)
                return .none
            }
        }
    }
}


import Foundation

public protocol CallbackEvent {
    associatedtype Info
    var info: Info { get }
}

public enum CallbackEvents {}

public struct CallbackManager {
    fileprivate var observers = [Any]()

    public init() {}

    public init(observers: (inout CallbackManager) -> Void) {
        var manager = CallbackManager()
        observers(&manager)
        self = manager
    }

    public mutating func on<Event: CallbackEvent>(
        _: Event.Type = Event.self,
        _ handler: @escaping (Event.Info) -> Void
    ) {
        observers.append(handler)
    }

    public func send<Event: CallbackEvent>(_ event: Event) {
        for case let observer as ((Event.Info) -> Void) in observers {
            observer(event.info)
        }
    }
}

public extension [CallbackManager] {
    func send<Event: CallbackEvent>(_ event: Event) {
        for cb in self {
            for case let observer as ((Event.Info) -> Void) in cb.observers {
                observer(event.info)
            }
        }
    }
}

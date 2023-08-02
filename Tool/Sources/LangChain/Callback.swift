import Foundation

public protocol CallbackEvent {
    associatedtype Info
    var info: Info { get }
}

public struct CallbackEvents {
    private init() {}
}

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

    public mutating func on<Event: CallbackEvent>(
        _: KeyPath<CallbackEvents, Event.Type>,
        _ handler: @escaping (Event.Info) -> Void
    ) {
        observers.append(handler)
    }

    public func send<Event: CallbackEvent>(_ event: Event) {
        for case let observer as ((Event.Info) -> Void) in observers {
            observer(event.info)
        }
    }

    func send<Event: CallbackEvent>(
        _: KeyPath<CallbackEvents, Event.Type>,
        _ info: Event.Info
    ) {
        for case let observer as ((Event.Info) -> Void) in observers {
            observer(info)
        }
    }
}

public extension [CallbackManager] {
    func send<Event: CallbackEvent>(_ event: Event) {
        for cb in self { cb.send(event) }
    }

    func send<Event: CallbackEvent>(
        _ keyPath: KeyPath<CallbackEvents, Event.Type>,
        _ info: Event.Info
    ) {
        for cb in self { cb.send(keyPath, info) }
    }
}


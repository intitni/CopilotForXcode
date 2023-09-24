import Foundation

public protocol CallbackEvent {
    associatedtype Info
    var info: Info { get }
}

public struct CallbackEvents {
    public struct UnTypedEvent: CallbackEvent {
        public var info: String
        public init(info: String) {
            self.info = info
        }
    }
    
    public var untyped: UnTypedEvent.Type { UnTypedEvent.self }
    
    private init() {}
}

public struct CallbackManager {
    struct Observer<Event: CallbackEvent> {
        let handler: (Event.Info) -> Void
    }
    
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
        observers.append(Observer<Event>(handler: handler))
    }

    public mutating func on<Event: CallbackEvent>(
        _: KeyPath<CallbackEvents, Event.Type>,
        _ handler: @escaping (Event.Info) -> Void
    ) {
        observers.append(Observer<Event>(handler: handler))
    }

    public func send<Event: CallbackEvent>(_ event: Event) {
        for case let observer as Observer<Event> in observers {
            observer.handler(event.info)
        }
    }

    func send<Event: CallbackEvent>(
        _: KeyPath<CallbackEvents, Event.Type>,
        _ info: Event.Info
    ) {
        for case let observer as Observer<Event> in observers {
            observer.handler(info)
        }
    }
    
    public func send(_ string: String) {
        for case let observer as Observer<CallbackEvents.UnTypedEvent> in observers {
            observer.handler(string)
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
    
    func send(_ event: String) {
        for cb in self { cb.send(event) }
    }
}


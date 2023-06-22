import AppKit
import ApplicationServices
import Foundation

public final class AXNotificationStream: AsyncSequence {
    public typealias Stream = AsyncStream<Element>
    public typealias Continuation = Stream.Continuation
    public typealias AsyncIterator = Stream.AsyncIterator
    public typealias Element = (name: String, element: AXUIElement, info: CFDictionary)

    private var continuation: Continuation
    private let stream: Stream

    public func makeAsyncIterator() -> Stream.AsyncIterator {
        stream.makeAsyncIterator()
    }

    deinit {
        continuation.finish()
    }
    
    public convenience init(
        app: NSRunningApplication,
        element: AXUIElement? = nil,
        notificationNames: String...
    ) {
        self.init(app: app, element: element, notificationNames: notificationNames)
    }

    public init(
        app: NSRunningApplication,
        element: AXUIElement? = nil,
        notificationNames: [String]
    ) {
        var cont: Continuation!
        stream = Stream { continuation in
            cont = continuation
        }
        continuation = cont
        var observer: AXObserver?

        func callback(
            observer: AXObserver,
            element: AXUIElement,
            notificationName: CFString,
            userInfo: CFDictionary,
            pointer: UnsafeMutableRawPointer?
        ) {
            guard let pointer = pointer?.assumingMemoryBound(to: Continuation.self)
            else { return }
            pointer.pointee.yield((notificationName as String, element, userInfo))
        }

        _ = AXObserverCreateWithInfoCallback(
            app.processIdentifier,
            callback,
            &observer
        )
        guard let observer else {
            continuation.finish()
            return
        }

        let observingElement = element ?? AXUIElementCreateApplication(app.processIdentifier)
        continuation.onTermination = { @Sendable _ in
            for name in notificationNames {
                AXObserverRemoveNotification(observer, observingElement, name as CFString)
            }
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
        }
        for name in notificationNames {
            AXObserverAddNotification(observer, observingElement, name as CFString, &continuation)
        }
        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            AXObserverGetRunLoopSource(observer),
            .commonModes
        )
    }
}

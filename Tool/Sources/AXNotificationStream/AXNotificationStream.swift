import AppKit
import ApplicationServices
import Foundation
import Logger

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

        Task { [weak self] in
            CFRunLoopAddSource(
                CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(observer),
                .commonModes
            )
            var pendingRegistrationNames = Set(notificationNames)
            var retry = 0
            while !pendingRegistrationNames.isEmpty, retry < 100 {
                guard let self else { return }
                retry += 1
                for name in notificationNames {
                    let e = withUnsafeMutablePointer(to: &self.continuation) { pointer in
                        AXObserverAddNotification(
                            observer,
                            observingElement,
                            name as CFString,
                            pointer
                        )
                    }
                    switch e {
                    case .success:
                        pendingRegistrationNames.remove(name)
                    case .actionUnsupported:
                        Logger.service.error("AXObserver: Action unsupported: \(name)")
                        pendingRegistrationNames.remove(name)
                    case .apiDisabled:
                        Logger.service.error("AXObserver: Accessibility API disabled, will try again later")
                        retry -= 1
                    case .invalidUIElement:
                        Logger.service.error("AXObserver: Invalid UI element")
                        pendingRegistrationNames.remove(name)
                    case .invalidUIElementObserver:
                        Logger.service.error("AXObserver: Invalid UI element observer")
                        pendingRegistrationNames.remove(name)
                    case .cannotComplete:
                        Logger.service
                            .error("AXObserver: Failed to observe \(name), will try again later")
                    case .notificationUnsupported:
                        Logger.service.error("AXObserver: Notification unsupported: \(name)")
                        pendingRegistrationNames.remove(name)
                    case .notificationAlreadyRegistered:
                        pendingRegistrationNames.remove(name)
                    default:
                        Logger.service
                            .error("AXObserver: Unrecognized error \(e) when registering \(name), will try again later")
                    }
                }
                try await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }
}


import AppKit
import ApplicationServices
import Foundation
import Logger
import Preferences

public final class AXNotificationStream: AsyncSequence {
    public typealias Stream = AsyncStream<Element>
    public typealias Continuation = Stream.Continuation
    public typealias AsyncIterator = Stream.AsyncIterator
    public typealias Element = (name: String, element: AXUIElement, info: CFDictionary)

    private var continuation: Continuation
    private let stream: Stream

    private let file: StaticString
    private let line: UInt
    private let function: StaticString

    public func makeAsyncIterator() -> Stream.AsyncIterator {
        stream.makeAsyncIterator()
    }

    deinit {
        continuation.finish()
    }

    public convenience init(
        app: NSRunningApplication,
        element: AXUIElement? = nil,
        notificationNames: String...,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        self.init(
            app: app,
            element: element,
            notificationNames: notificationNames,
            file: file,
            line: line,
            function: function
        )
    }

    public init(
        app: NSRunningApplication,
        element: AXUIElement? = nil,
        notificationNames: [String],
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        self.file = file
        self.line = line
        self.function = function

        let mode: CFRunLoopMode = UserDefaults.shared
            .value(for: \.observeToAXNotificationWithDefaultMode) ? .defaultMode : .commonModes

        let runLoop: CFRunLoop = CFRunLoopGetMain()

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
                runLoop,
                AXObserverGetRunLoopSource(observer),
                mode
            )
        }

        Task { @MainActor [weak self] in
            CFRunLoopAddSource(
                runLoop,
                AXObserverGetRunLoopSource(observer),
                mode
            )
            var pendingRegistrationNames = Set(notificationNames)
            var retry = 0
            while !pendingRegistrationNames.isEmpty, retry < 100 {
                guard let self else { return }
                retry += 1
                for name in notificationNames {
                    await Task.yield()
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
                        Logger.service
                            .error("AXObserver: Accessibility API disabled, will try again later")
                        retry -= 1
                    case .invalidUIElement:
                        Logger.service
                            .error("AXObserver: Invalid UI element, notification name \(name)")
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
                        Logger.service.info("AXObserver: Notification already registered: \(name)")
                        pendingRegistrationNames.remove(name)
                    default:
                        Logger.service
                            .error(
                                "AXObserver: Unrecognized error \(e) when registering \(name), will try again later"
                            )
                    }
                }
                try await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }
}


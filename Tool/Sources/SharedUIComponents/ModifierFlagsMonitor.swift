import Cocoa
import Foundation
import SwiftUI

public extension View {
    func modifierFlagsMonitor(local: Bool = true) -> some View {
        ModifierFlagsMonitorWrapper(local: local) { self }
    }
}

public extension EnvironmentValues {
    var modifierFlags: NSEvent.ModifierFlags {
        get { self[ModifierFlagsEnvironmentKey.self] }
        set { self[ModifierFlagsEnvironmentKey.self] = newValue }
    }
}

final class ModifierFlagsMonitor {
    private var monitor: Any?

    deinit { stop() }

    func start(binding: Binding<NSEvent.ModifierFlags>, local: Bool) {
        guard monitor == nil else { return }
        if local {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
                binding.wrappedValue = event.modifierFlags
                return event
            }
        } else {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { event in
                binding.wrappedValue = event.modifierFlags
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

struct ModifierFlagsMonitorWrapper<Content: View>: View {
    var local = true
    @ViewBuilder let content: () -> Content
    @State private var modifierFlags: NSEvent.ModifierFlags = []
    @State private var eventMonitor = ModifierFlagsMonitor()

    var body: some View {
        content()
            .environment(\.modifierFlags, modifierFlags)
            .onAppear { eventMonitor.start(binding: $modifierFlags, local: local) }
            .onDisappear { eventMonitor.stop() }
    }
}

struct ModifierFlagsEnvironmentKey: EnvironmentKey {
    static let defaultValue: NSEvent.ModifierFlags = []
}


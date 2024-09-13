import Cocoa
import Foundation
import SwiftUI

public extension View {
    func modifierFlagsMonitor() -> some View {
        ModifierFlagsMonitorWrapper { self }
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

    func start(binding: Binding<NSEvent.ModifierFlags>) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            binding.wrappedValue = event.modifierFlags
            return event
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
    @ViewBuilder let content: () -> Content
    @State private var modifierFlags: NSEvent.ModifierFlags = []
    @State private var eventMonitor = ModifierFlagsMonitor()

    var body: some View {
        content()
            .environment(\.modifierFlags, modifierFlags)
            .onAppear { eventMonitor.start(binding: $modifierFlags) }
            .onDisappear { eventMonitor.stop() }
    }
}

struct ModifierFlagsEnvironmentKey: EnvironmentKey {
    static let defaultValue: NSEvent.ModifierFlags = []
}


import AppKit
import Service
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let scheduledCleaner = ScheduledCleaner()

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

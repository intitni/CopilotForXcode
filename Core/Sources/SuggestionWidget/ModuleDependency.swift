import ActiveApplicationMonitor
import AppKit
import ComposableArchitecture
import Dependencies
import Foundation
import Preferences
import UserDefaultsObserver
import XcodeInspector

public final class SuggestionWidgetControllerDependency {
    public var suggestionWidgetDataSource: SuggestionWidgetDataSource?
    public var onOpenChatClicked: () -> Void = {}
    public var onCustomCommandClicked: (CustomCommand) -> Void = { _ in }
}

@MainActor
public final class Windows {
    var fullscreenDetector: NSWindow!
    var widgetWindow: NSWindow!
    var tabWindow: NSWindow!
    var sharedPanelWindow: NSWindow!
    var suggestionPanelWindow: NSWindow!
    var chatPanelWindow: NSWindow!

    nonisolated
    init() {}

    func orderFront() {
        widgetWindow?.orderFrontRegardless()
        tabWindow?.orderFrontRegardless()
        sharedPanelWindow?.orderFrontRegardless()
        suggestionPanelWindow?.orderFrontRegardless()
        chatPanelWindow?.orderFrontRegardless()
    }
}

public final class UserDefaultsObservers {
    let presentationModeChangeObserver = UserDefaultsObserver(
        object: UserDefaults.shared,
        forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionPresentationMode.key,
        ], context: nil
    )
    let colorSchemeChangeObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().widgetColorScheme.key,
        ], context: nil
    )
    let systemColorSchemeChangeObserver = UserDefaultsObserver(
        object: UserDefaults.standard, forKeyPaths: ["AppleInterfaceStyle"], context: nil
    )
}

struct SuggestionWidgetControllerDependencyKey: DependencyKey {
    static let liveValue = SuggestionWidgetControllerDependency()
}

struct WindowsDependencyKey: DependencyKey {
    static let liveValue = Windows()
}

struct UserDefaultsDependencyKey: DependencyKey {
    static let liveValue = UserDefaultsObservers()
}

struct XcodeInspectorKey: DependencyKey {
    static let liveValue = XcodeInspector.shared
}

struct ActiveApplicationMonitorKey: DependencyKey {
    static let liveValue = ActiveApplicationMonitor.self
}

extension DependencyValues {
    var suggestionWidgetControllerDependency: SuggestionWidgetControllerDependency {
        get { self[SuggestionWidgetControllerDependencyKey.self] }
        set { self[SuggestionWidgetControllerDependencyKey.self] = newValue }
    }

    var windows: Windows {
        get { self[WindowsDependencyKey.self] }
        set { self[WindowsDependencyKey.self] = newValue }
    }

    var userDefaultsObservers: UserDefaultsObservers {
        get { self[UserDefaultsDependencyKey.self] }
        set { self[UserDefaultsDependencyKey.self] = newValue }
    }

    var xcodeInspector: XcodeInspector {
        get { self[XcodeInspectorKey.self] }
        set { self[XcodeInspectorKey.self] = newValue }
    }

    var activeApplicationMonitor: ActiveApplicationMonitor.Type {
        get { self[ActiveApplicationMonitorKey.self] }
        set { self[ActiveApplicationMonitorKey.self] = newValue }
    }
}


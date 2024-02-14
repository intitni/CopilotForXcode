import ActiveApplicationMonitor
import AppKit
import ChatTab
import ComposableArchitecture
import Dependencies
import Foundation
import Preferences
import SwiftUI
import UserDefaultsObserver
import XcodeInspector

public final class SuggestionWidgetControllerDependency {
    public var suggestionWidgetDataSource: SuggestionWidgetDataSource?
    public var onOpenChatClicked: () -> Void = {}
    public var onCustomCommandClicked: (CustomCommand) -> Void = { _ in }
    var windowsController: WidgetWindowsController?

    public init() {}
}

public final class WidgetUserDefaultsObservers {
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

    public init() {}
}

struct SuggestionWidgetControllerDependencyKey: DependencyKey {
    static let liveValue = SuggestionWidgetControllerDependency()
}

struct UserDefaultsDependencyKey: DependencyKey {
    static let liveValue = WidgetUserDefaultsObservers()
}

struct XcodeInspectorKey: DependencyKey {
    static let liveValue = XcodeInspector.shared
}

struct ActiveApplicationMonitorKey: DependencyKey {
    static let liveValue = ActiveApplicationMonitor.shared
}

struct ChatTabBuilderCollectionKey: DependencyKey {
    static let liveValue: () -> [ChatTabBuilderCollection] = { [] }
}

public extension DependencyValues {
    var suggestionWidgetControllerDependency: SuggestionWidgetControllerDependency {
        get { self[SuggestionWidgetControllerDependencyKey.self] }
        set { self[SuggestionWidgetControllerDependencyKey.self] = newValue }
    }

    var suggestionWidgetUserDefaultsObservers: WidgetUserDefaultsObservers {
        get { self[UserDefaultsDependencyKey.self] }
        set { self[UserDefaultsDependencyKey.self] = newValue }
    }

    var chatTabBuilderCollection: () -> [ChatTabBuilderCollection] {
        get { self[ChatTabBuilderCollectionKey.self] }
        set { self[ChatTabBuilderCollectionKey.self] = newValue }
    }
}

extension DependencyValues {
    var xcodeInspector: XcodeInspector {
        get { self[XcodeInspectorKey.self] }
        set { self[XcodeInspectorKey.self] = newValue }
    }

    var activeApplicationMonitor: ActiveApplicationMonitor {
        get { self[ActiveApplicationMonitorKey.self] }
        set { self[ActiveApplicationMonitorKey.self] = newValue }
    }
}


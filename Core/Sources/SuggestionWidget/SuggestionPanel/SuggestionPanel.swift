import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import Perception
import SwiftUI
import UserDefaultsObserver
import Workspace
import XcodeInspector

@Perceptible
public class SuggestionPanel {
    var suggestionManager: PresentingCodeSuggestionManager?
    var colorScheme: ColorScheme = .light
    var verticalAlignment: VerticalAlignment = .top
    var horizontalAlignment: HorizontalAlignment = .leading
    var isPanelDisplayed: Bool = false
    var isPanelOutOfFrame: Bool = false
    var frame = CGRect.zero
    let userDefaultObservers = WidgetUserDefaultsObservers()
    @MainActor
    var opacity: Double {
        guard isPanelDisplayed else { return 0 }
        if isPanelOutOfFrame { return 0 }
        guard let suggestionManager,
              !suggestionManager.displaySuggestions.suggestions.isEmpty
        else { return 0 }
        return 1
    }

    private var cancellable = Set<AnyCancellable>()

    public init() {
        observeToColorSchemeChanges()
        observeToActiveDocumentChanges()
    }

    func updateLocation(_ location: WidgetLocation) {
        switch UserDefaults.shared.value(for: \.suggestionPresentationMode) {
        case .floatingWidget:
            verticalAlignment = location.sharedPanelLocation.alignPanelTop ? .top : .bottom
            horizontalAlignment = location.sharedPanelLocation.alignPanelLeft ? .leading : .trailing
            isPanelOutOfFrame = false
            frame = location.sharedPanelLocation.frame
        case .nearbyTextCursor:
            verticalAlignment = location.suggestionPanelLocation?
                .alignPanelTop ?? false ? .top : .bottom
            horizontalAlignment = location.suggestionPanelLocation?
                .alignPanelLeft ?? false ? .leading : .trailing
            isPanelOutOfFrame = location.suggestionPanelLocation == nil
            frame = location.suggestionPanelLocation?.frame ?? .zero
        }
    }
}

private extension SuggestionPanel {
    func observeToActiveDocumentChanges() {
        XcodeInspector.shared.$activeDocumentURL
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { url in
                guard let url = url else {
                    self.suggestionManager = nil
                    return
                }
                Task {
                    @Dependency(\.workspacePool) var workspacePool
                    do {
                        let (_, filespace) = try await workspacePool
                            .fetchOrCreateWorkspaceAndFilespace(fileURL: url)
                        await MainActor.run {
                            self.suggestionManager =
                                PresentingCodeSuggestionManager(filespace: filespace)
                        }
                    } catch {
                        self.suggestionManager = nil
                    }
                }
            }.store(in: &cancellable)
    }

    func observeToColorSchemeChanges() {
        userDefaultObservers.systemColorSchemeChangeObserver.onChange = { [weak self] in
            guard let self else { return }
            let widgetColorScheme = UserDefaults.shared.value(for: \.widgetColorScheme)
            let systemColorScheme: ColorScheme = NSApp.effectiveAppearance.name == .darkAqua
                ? .dark
                : .light

            let scheme: ColorScheme = {
                switch (widgetColorScheme, systemColorScheme) {
                case (.system, .dark), (.dark, _):
                    return .dark
                case (.system, .light), (.light, _):
                    return .light
                case (.system, _):
                    return .light
                }
            }()
            Task { @MainActor in self.colorScheme = scheme }
        }
    }
}


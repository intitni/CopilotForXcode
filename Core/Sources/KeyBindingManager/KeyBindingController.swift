import ActiveApplicationMonitor
import AppKit
import CGEventOverride
import Combine
import CommandHandler
import Dependencies
import Foundation
import Logger
import Preferences
import SuggestionBasic
import UserDefaultsObserver
import Workspace
import WorkspaceSuggestionService
import XcodeInspector

protocol KeyBindingHandler {
    var isOn: Bool { get }
    func handleEvent(_ event: CGEvent) -> CGEventManipulation.Result
}

final class KeyBindingController {
    let hook: CGEventHookType = CGEventHook(eventsOfInterest: [.keyDown]) { message in
        Logger.service.debug("TabToAcceptSuggestion: \(message)")
    }

    private var CGEventObservationTask: Task<Void, Error>?
    private var isObserving: Bool { CGEventObservationTask != nil }
    private let userDefaultsObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().acceptSuggestionWithTab.key,
            UserDefaultPreferenceKeys().dismissSuggestionWithEsc.key,
        ], context: nil
    )
    private var stoppedForExit = false
    var eventHandlers: [KeyBindingHandler] = [TabToAcceptSuggestionHandler()]

    struct ObservationKey: Hashable {}

    @MainActor
    func stopForExit() {
        stoppedForExit = true
        stopObservation()
    }

    init() {
        _ = ThreadSafeAccessToXcodeInspector.shared

        hook.add(
            .init(
                eventsOfInterest: [.keyDown],
                convert: { [weak self] _, _, event in
                    self?.handleEvent(event) ?? .unchanged
                }
            ),
            forKey: ObservationKey()
        )
    }

    func start() {
        Task { [weak self] in
            for await _ in ActiveApplicationMonitor.shared.createInfoStream() {
                guard let self else { return }
                try Task.checkCancellation()
                Task { @MainActor in
                    if ActiveApplicationMonitor.shared.activeXcode != nil {
                        self.startObservation()
                    } else {
                        self.stopObservation()
                    }
                }
            }
        }

        userDefaultsObserver.onChange = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                for handler in self.eventHandlers {
                    if handler.isOn {
                        self.startObservation()
                        return
                    }
                }
                self.stopObservation()
            }
        }
    }

    @MainActor
    func startObservation() {
        guard !stoppedForExit else { return }
        guard eventHandlers.contains(where: { $0.isOn }) else { return }
        hook.activateIfPossible()
    }

    @MainActor
    func stopObservation() {
        hook.deactivate()
    }

    func handleEvent(_ event: CGEvent) -> CGEventManipulation.Result {
        for handler in eventHandlers {
            if handler.isOn {
                let result = handler.handleEvent(event)
                switch result {
                case .unchanged: continue
                default: return result
                }
            }
        }
        return .unchanged
    }
}

final class ThreadSafeAccessToXcodeInspector {
    static let shared = ThreadSafeAccessToXcodeInspector()

    private(set) var activeDocumentURL: URL?
    private(set) var activeXcode: AppInstanceInspector?
    private(set) var focusedEditor: SourceEditor?
    private var cancellable: Set<AnyCancellable> = []

    init() {
        let inspector = XcodeInspector.shared

        inspector.$activeDocumentURL.receive(on: DispatchQueue.main).sink { [weak self] newValue in
            self?.activeDocumentURL = newValue
        }.store(in: &cancellable)

        inspector.$activeXcode.receive(on: DispatchQueue.main).sink { [weak self] newValue in
            self?.activeXcode = newValue
        }.store(in: &cancellable)

        inspector.$focusedEditor.receive(on: DispatchQueue.main).sink { [weak self] newValue in
            self?.focusedEditor = newValue
        }.store(in: &cancellable)
    }
}


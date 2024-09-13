import Client
import ComposableArchitecture
import Foundation
import LaunchAgentManager
import SwiftUI
import XPCShared

@Reducer
struct General {
    @ObservableState
    struct State: Equatable {
        var xpcServiceVersion: String?
        var isAccessibilityPermissionGranted: Bool?
        var isReloading = false
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action {
        case appear
        case setupLaunchAgentIfNeeded
        case setupLaunchAgentClicked
        case removeLaunchAgentClicked
        case reloadLaunchAgentClicked
        case openExtensionManager
        case reloadStatus
        case finishReloading(xpcServiceVersion: String, permissionGranted: Bool)
        case failedReloading
        case alert(PresentationAction<Alert>)

        case setupLaunchAgent
        case finishSetupLaunchAgent
        case finishRemoveLaunchAgent
        case finishReloadLaunchAgent

        @CasePathable
        enum Alert: Equatable {
            case moveToApplications
            case moveTo(URL)
            case install
        }
    }

    @Dependency(\.toast) var toast

    struct ReloadStatusCancellableId: Hashable {}

    static var didWarnInstallationPosition: Bool {
        get { UserDefaults.standard.bool(forKey: "didWarnInstallationPosition") }
        set { UserDefaults.standard.set(newValue, forKey: "didWarnInstallationPosition") }
    }

    static var bundleIsInApplicationsFolder: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications")
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appear:
                if Self.bundleIsInApplicationsFolder {
                    return .run { send in
                        await send(.setupLaunchAgentIfNeeded)
                    }
                }

                if !Self.didWarnInstallationPosition {
                    Self.didWarnInstallationPosition = true
                    state.alert = .init {
                        TextState("Move to Applications Folder?")
                    } actions: {
                        ButtonState(action: .moveToApplications) {
                            TextState("Move")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Not Now")
                        }
                    } message: {
                        TextState(
                            "To ensure the best experience, please move the app to the Applications folder. If the app is not inside the Applications folder, please set up the launch agent manually by clicking the button."
                        )
                    }
                }

                return .none

            case .setupLaunchAgentIfNeeded:
                return .run { send in
                    #if DEBUG
                    // do not auto install on debug build
                    #else
                    do {
                        try await LaunchAgentManager()
                            .setupLaunchAgentForTheFirstTimeIfNeeded()
                    } catch {
                        toast(error.localizedDescription, .error)
                    }
                    #endif
                    await send(.reloadStatus)
                }

            case .setupLaunchAgentClicked:
                if Self.bundleIsInApplicationsFolder {
                    return .run { send in
                        await send(.setupLaunchAgent)
                    }
                }

                state.alert = .init {
                    TextState("Setup Launch Agent")
                } actions: {
                    ButtonState(action: .install) {
                        TextState("Setup")
                    }

                    ButtonState(action: .moveToApplications) {
                        TextState("Move to Applications Folder")
                    }

                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState(
                        "It's recommended to move the app into the Applications folder. But you can still keep it in the current folder and install the launch agent to ~/Library/LaunchAgents."
                    )
                }

                return .none

            case .removeLaunchAgentClicked:
                return .run { send in
                    do {
                        try await LaunchAgentManager().removeLaunchAgent()
                        await send(.finishRemoveLaunchAgent)
                    } catch {
                        toast(error.localizedDescription, .error)
                    }
                    await send(.reloadStatus)
                }

            case .reloadLaunchAgentClicked:
                return .run { send in
                    do {
                        try await LaunchAgentManager().reloadLaunchAgent()
                        await send(.finishReloadLaunchAgent)
                    } catch {
                        toast(error.localizedDescription, .error)
                    }
                    await send(.reloadStatus)
                }

            case .setupLaunchAgent:
                return .run { send in
                    do {
                        try await LaunchAgentManager().setupLaunchAgent()
                        await send(.finishSetupLaunchAgent)
                    } catch {
                        toast(error.localizedDescription, .error)
                    }
                    await send(.reloadStatus)
                }

            case .finishSetupLaunchAgent:
                state.alert = .init {
                    TextState("Launch Agent Installed")
                } actions: {
                    ButtonState {
                        TextState("OK")
                    }
                } message: {
                    TextState(
                        "The launch agent has been installed. Please restart the app."
                    )
                }
                return .none

            case .finishRemoveLaunchAgent:
                state.alert = .init {
                    TextState("Launch Agent Removed")
                } actions: {
                    ButtonState {
                        TextState("OK")
                    }
                } message: {
                    TextState(
                        "The launch agent has been removed."
                    )
                }
                return .none

            case .finishReloadLaunchAgent:
                state.alert = .init {
                    TextState("Launch Agent Reloaded")
                } actions: {
                    ButtonState {
                        TextState("OK")
                    }
                } message: {
                    TextState(
                        "The launch agent has been reloaded."
                    )
                }
                return .none

            case .openExtensionManager:
                return .run { send in
                    let service = try getService()
                    do {
                        _ = try await service
                            .send(requestBody: ExtensionServiceRequests.OpenExtensionManager())
                    } catch {
                        toast(error.localizedDescription, .error)
                        await send(.failedReloading)
                    }
                }

            case .reloadStatus:
                state.isReloading = true
                return .run { send in
                    let service = try getService()
                    do {
                        let isCommunicationReady = try await service.launchIfNeeded()
                        if isCommunicationReady {
                            let xpcServiceVersion = try await service.getXPCServiceVersion().version
                            let isAccessibilityPermissionGranted = try await service
                                .getXPCServiceAccessibilityPermission()
                            await send(.finishReloading(
                                xpcServiceVersion: xpcServiceVersion,
                                permissionGranted: isAccessibilityPermissionGranted
                            ))
                        } else {
                            toast("Launching service app.", .info)
                            try await Task.sleep(nanoseconds: 5_000_000_000)
                            await send(.reloadStatus)
                        }
                    } catch let error as XPCCommunicationBridgeError {
                        toast(
                            "Failed to reach communication bridge. \(error.localizedDescription)",
                            .error
                        )
                        await send(.failedReloading)
                    } catch {
                        toast(error.localizedDescription, .error)
                        await send(.failedReloading)
                    }
                }.cancellable(id: ReloadStatusCancellableId(), cancelInFlight: true)

            case let .finishReloading(version, granted):
                state.xpcServiceVersion = version
                state.isAccessibilityPermissionGranted = granted
                state.isReloading = false
                return .none

            case .failedReloading:
                state.isReloading = false
                return .none

            case let .alert(.presented(action)):
                switch action {
                case .moveToApplications:
                    return .run { send in
                        let appURL = URL(fileURLWithPath: "/Applications")
                        await send(.alert(.presented(.moveTo(appURL))))
                    }

                case let .moveTo(url):
                    return .run { _ in
                        do {
                            try FileManager.default.moveItem(
                                at: Bundle.main.bundleURL,
                                to: url.appendingPathComponent(
                                    Bundle.main.bundleURL.lastPathComponent
                                )
                            )
                            await NSApplication.shared.terminate(nil)
                        } catch {
                            toast(error.localizedDescription, .error)
                        }
                    }
                case .install:
                    return .run { send in
                        await send(.setupLaunchAgent)
                    }
                }

            case .alert(.dismiss):
                state.alert = nil
                return .none
            }
        }
    }
}


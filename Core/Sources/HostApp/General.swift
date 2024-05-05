import Client
import ComposableArchitecture
import Foundation
import LaunchAgentManager
import SwiftUI
import XPCShared

struct General: ReducerProtocol {
    struct State: Equatable {
        var xpcServiceVersion: String?
        var isAccessibilityPermissionGranted: Bool?
        var isReloading = false
    }

    enum Action: Equatable {
        case appear
        case setupLaunchAgentIfNeeded
        case openExtensionManager
        case reloadStatus
        case finishReloading(xpcServiceVersion: String, permissionGranted: Bool)
        case failedReloading
    }

    @Dependency(\.toast) var toast

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in
                    await send(.setupLaunchAgentIfNeeded)
                }

            case .setupLaunchAgentIfNeeded:
                return .run { send in
                    #if DEBUG
                    // do not auto install on debug build
                    #else
                    Task {
                        do {
                            try await LaunchAgentManager()
                                .setupLaunchAgentForTheFirstTimeIfNeeded()
                        } catch {
                            toast(error.localizedDescription, .error)
                        }
                    }
                    #endif
                    await send(.reloadStatus)
                }

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
                }

            case let .finishReloading(version, granted):
                state.xpcServiceVersion = version
                state.isAccessibilityPermissionGranted = granted
                state.isReloading = false
                return .none

            case .failedReloading:
                state.isReloading = false
                return .none
            }
        }
    }
}


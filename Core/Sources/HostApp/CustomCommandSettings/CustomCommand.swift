import ComposableArchitecture
import Foundation
import PlusFeatureFlag
import Preferences
import SwiftUI
import Toast

@Reducer
struct CustomCommandFeature {
    @ObservableState
    struct State: Equatable {
        var editCustomCommand: EditCustomCommand.State?
    }

    let settings: CustomCommandView.Settings

    enum Action: Equatable {
        case createNewCommand
        case editCommand(CustomCommand)
        case editCustomCommand(EditCustomCommand.Action)
        case deleteCommand(CustomCommand)
        case exportCommand(CustomCommand)
        case importCommand(at: URL)
        case importCommandClicked
    }

    @Dependency(\.toast) var toast

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .createNewCommand:
                if !isFeatureAvailable(\.unlimitedCustomCommands),
                   settings.customCommands.count >= 10
                {
                    toast("Upgrade to Plus to add more commands", .info)
                    return .none
                }
                state.editCustomCommand = EditCustomCommand.State(nil)
                return .none
            case let .editCommand(command):
                state.editCustomCommand = EditCustomCommand.State(command)
                return .none
            case .editCustomCommand(.close):
                state.editCustomCommand = nil
                return .none
            case let .deleteCommand(command):
                settings.customCommands.removeAll(
                    where: { $0.id == command.id }
                )
                if state.editCustomCommand?.commandId == command.id {
                    state.editCustomCommand = nil
                }
                return .none
            case .editCustomCommand:
                return .none
            case let .exportCommand(command):
                return .run { _ in
                    do {
                        let data = try JSONEncoder().encode(command)
                        let filename = "CustomCommand-\(command.name).json"

                        let url = await withCheckedContinuation { continuation in
                            Task { @MainActor in
                                let panel = NSSavePanel()
                                panel.canCreateDirectories = true
                                panel.nameFieldStringValue = filename
                                let result = await panel.begin()
                                switch result {
                                case .OK:
                                    continuation.resume(returning: panel.url)
                                default:
                                    continuation.resume(returning: nil)
                                }
                            }
                        }

                        if let url {
                            try data.write(to: url)
                            toast("Saved!", .info)
                        }

                    } catch {
                        toast(error.localizedDescription, .error)
                    }
                }

            case let .importCommand(url):
                if !isFeatureAvailable(\.unlimitedCustomCommands),
                   settings.customCommands.count >= 10
                {
                    toast("Upgrade to Plus to add more commands", .info)
                    return .none
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    var command = try JSONDecoder().decode(CustomCommand.self, from: data)
                    command.commandId = UUID().uuidString
                    settings.customCommands.append(command)
                    toast("Imported custom command \(command.name)!", .info)
                } catch {
                    toast("Failed to import command: \(error.localizedDescription)", .error)
                }
                return .none

            case .importCommandClicked:
                return .run { send in
                    let url = await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.json]
                            let result = await panel.begin()
                            if result == .OK {
                                continuation.resume(returning: panel.url)
                            } else {
                                continuation.resume(returning: nil)
                            }
                        }
                    }
                    
                    if let url {
                        await send(.importCommand(at: url))
                    }
                }
            }
        }.ifLet(\.editCustomCommand, action: \.editCustomCommand) {
            EditCustomCommand(settings: settings)
        }
    }
}


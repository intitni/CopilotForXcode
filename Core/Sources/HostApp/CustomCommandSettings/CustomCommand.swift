import ComposableArchitecture
import Foundation
import Preferences
import SwiftUI

struct CustomCommandFeature: ReducerProtocol {
    struct State: Equatable {
        var editCustomCommand: EditCustomCommand.State?
    }
    
    let settings: CustomCommandView.Settings
    
    enum Action: Equatable {
        case createNewCommand
        case editCommand(CustomCommand)
        case editCustomCommand(EditCustomCommand.Action)
        case deleteCommand(CustomCommand)
    }
    
    @Dependency(\.toastController) var toastController
    
    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .createNewCommand:
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
                
            }
        }.ifLet(\.editCustomCommand, action: /Action.editCustomCommand) {
            EditCustomCommand(settings: settings)
        }
    }
}

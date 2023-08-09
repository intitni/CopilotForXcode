import ComposableArchitecture
import Foundation
import Preferences
import SwiftUI

struct EditCustomCommand: ReducerProtocol {
    enum CommandType: Int, CaseIterable, Equatable {
        case sendMessage
        case promptToCode
        case customChat
        case singleRoundDialog
    }

    struct State: Equatable {
        @BindingState var name: String = ""
        @BindingState var commandType: CommandType = .sendMessage
        var isNewCommand: Bool = false
        let commandId: String

        var sendMessage = EditSendMessageCommand.State()
        var promptToCode = EditPromptToCodeCommand.State()
        var customChat = EditCustomChatCommand.State()
        var singleRoundDialog = EditSingleRoundDialogCommand.State()

        init(_ command: CustomCommand?) {
            isNewCommand = command == nil
            commandId = command?.id ?? UUID().uuidString
            name = command?.name ?? "New Command"

            switch command?.feature {
            case let .chatWithSelection(extraSystemPrompt, prompt, useExtraSystemPrompt):
                commandType = .sendMessage
                sendMessage = .init(
                    extraSystemPrompt: extraSystemPrompt ?? "",
                    useExtraSystemPrompt: useExtraSystemPrompt ?? false,
                    prompt: prompt ?? ""
                )
            case .none:
                commandType = .sendMessage
                sendMessage = .init(
                    extraSystemPrompt: "",
                    useExtraSystemPrompt: false,
                    prompt: "Hello"
                )
            case let .customChat(systemPrompt, prompt):
                commandType = .customChat
                customChat = .init(
                    systemPrompt: systemPrompt ?? "",
                    prompt: prompt ?? ""
                )
            case let .singleRoundDialog(
                systemPrompt,
                overwriteSystemPrompt,
                prompt,
                receiveReplyInNotification
            ):
                commandType = .singleRoundDialog
                singleRoundDialog = .init(
                    systemPrompt: systemPrompt ?? "",
                    overwriteSystemPrompt: overwriteSystemPrompt ?? false,
                    prompt: prompt ?? "",
                    receiveReplyInNotification: receiveReplyInNotification ?? false
                )
            case let .promptToCode(extraSystemPrompt, prompt, continuousMode, generateDescription):
                commandType = .promptToCode
                promptToCode = .init(
                    extraSystemPrompt: extraSystemPrompt ?? "",
                    prompt: prompt ?? "",
                    continuousMode: continuousMode ?? false,
                    generateDescription: generateDescription ?? true
                )
            }
        }
    }

    enum Action: BindableAction, Equatable {
        case saveCommand
        case close
        case binding(BindingAction<State>)
        case sendMessage(EditSendMessageCommand.Action)
        case promptToCode(EditPromptToCodeCommand.Action)
        case customChat(EditCustomChatCommand.Action)
        case singleRoundDialog(EditSingleRoundDialogCommand.Action)
    }

    let settings: CustomCommandView.Settings

    @Dependency(\.toast) var toast

    var body: some ReducerProtocol<State, Action> {
        Scope(state: \.sendMessage, action: /Action.sendMessage) {
            EditSendMessageCommand()
        }

        Scope(state: \.promptToCode, action: /Action.promptToCode) {
            EditPromptToCodeCommand()
        }

        Scope(state: \.customChat, action: /Action.customChat) {
            EditCustomChatCommand()
        }

        Scope(state: \.singleRoundDialog, action: /Action.singleRoundDialog) {
            EditSingleRoundDialogCommand()
        }

        BindingReducer()

        Reduce { state, action in
            switch action {
            case .saveCommand:
                guard !state.name.isEmpty else {
                    toast("Command name cannot be empty.", .error)
                    return .none
                }

                let newCommand = CustomCommand(
                    commandId: state.commandId,
                    name: state.name,
                    feature: {
                        switch state.commandType {
                        case .sendMessage:
                            let state = state.sendMessage
                            return .chatWithSelection(
                                extraSystemPrompt: state.extraSystemPrompt,
                                prompt: state.prompt,
                                useExtraSystemPrompt: state.useExtraSystemPrompt
                            )
                        case .promptToCode:
                            let state = state.promptToCode
                            return .promptToCode(
                                extraSystemPrompt: state.extraSystemPrompt,
                                prompt: state.prompt,
                                continuousMode: state.continuousMode,
                                generateDescription: state.generateDescription
                            )
                        case .customChat:
                            let state = state.customChat
                            return .customChat(
                                systemPrompt: state.systemPrompt,
                                prompt: state.prompt
                            )
                        case .singleRoundDialog:
                            let state = state.singleRoundDialog
                            return .singleRoundDialog(
                                systemPrompt: state.systemPrompt,
                                overwriteSystemPrompt: state.overwriteSystemPrompt,
                                prompt: state.prompt,
                                receiveReplyInNotification: state.receiveReplyInNotification
                            )
                        }
                    }()
                )

                if state.isNewCommand {
                    settings.customCommands.append(newCommand)
                    state.isNewCommand = false
                    toast("The command is created.", .info)
                } else {
                    if let index = settings.customCommands.firstIndex(where: {
                        $0.id == newCommand.id
                    }) {
                        settings.customCommands[index] = newCommand
                    } else {
                        settings.customCommands.append(newCommand)
                    }
                    toast("The command is updated.", .info)
                }

                return .none

            case .close:
                return .none

            case .binding:
                return .none
            case .sendMessage:
                return .none
            case .promptToCode:
                return .none
            case .customChat:
                return .none
            case .singleRoundDialog:
                return .none
            }
        }
    }
}

struct EditSendMessageCommand: ReducerProtocol {
    struct State: Equatable {
        @BindingState var extraSystemPrompt: String = ""
        @BindingState var useExtraSystemPrompt: Bool = false
        @BindingState var prompt: String = ""
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { _, action in
            switch action {
            case .binding:
                return .none
            }
        }
    }
}

struct EditPromptToCodeCommand: ReducerProtocol {
    struct State: Equatable {
        @BindingState var extraSystemPrompt: String = ""
        @BindingState var prompt: String = ""
        @BindingState var continuousMode: Bool = false
        @BindingState var generateDescription: Bool = false
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
    }
}

struct EditCustomChatCommand: ReducerProtocol {
    struct State: Equatable {
        @BindingState var systemPrompt: String = ""
        @BindingState var prompt: String = ""
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
    }
}

struct EditSingleRoundDialogCommand: ReducerProtocol {
    struct State: Equatable {
        @BindingState var systemPrompt: String = ""
        @BindingState var overwriteSystemPrompt: Bool = false
        @BindingState var prompt: String = ""
        @BindingState var receiveReplyInNotification: Bool = false
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()
    }
}


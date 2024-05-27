import ComposableArchitecture
import Foundation
import Preferences
import SwiftUI

@Reducer
struct EditCustomCommand {
    enum CommandType: Int, CaseIterable, Equatable {
        case sendMessage
        case promptToCode
        case customChat
        case singleRoundDialog
    }

    @ObservableState
    struct State: Equatable {
        var name: String = ""
        var commandType: CommandType = .sendMessage
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

    var body: some ReducerOf<Self> {
        Scope(state: \.sendMessage, action: \.sendMessage) {
            EditSendMessageCommand()
        }

        Scope(state: \.promptToCode, action: \.promptToCode) {
            EditPromptToCodeCommand()
        }

        Scope(state: \.customChat, action: \.customChat) {
            EditCustomChatCommand()
        }

        Scope(state: \.singleRoundDialog, action: \.singleRoundDialog) {
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

@Reducer
struct EditSendMessageCommand {
    @ObservableState
    struct State: Equatable {
        var extraSystemPrompt: String = ""
        var useExtraSystemPrompt: Bool = false
        var prompt: String = ""
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { _, action in
            switch action {
            case .binding:
                return .none
            }
        }
    }
}

@Reducer
struct EditPromptToCodeCommand {
    @ObservableState
    struct State: Equatable {
        var extraSystemPrompt: String = ""
        var prompt: String = ""
        var continuousMode: Bool = false
        var generateDescription: Bool = false
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
    }
}

@Reducer
struct EditCustomChatCommand {
    @ObservableState
    struct State: Equatable {
        var systemPrompt: String = ""
        var prompt: String = ""
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
    }
}

@Reducer
struct EditSingleRoundDialogCommand {
    @ObservableState
    struct State: Equatable {
        var systemPrompt: String = ""
        var overwriteSystemPrompt: Bool = false
        var prompt: String = ""
        var receiveReplyInNotification: Bool = false
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
    }
}


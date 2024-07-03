import Preferences
import SharedUIComponents
import SwiftUI

#if canImport(ProHostApp)
import ProHostApp
#endif

struct ChatSettingsScopeSectionView: View {
    class Settings: ObservableObject {
        @AppStorage(\.enableFileScopeByDefaultInChatContext)
        var enableFileScopeByDefaultInChatContext: Bool
        @AppStorage(\.enableCodeScopeByDefaultInChatContext)
        var enableCodeScopeByDefaultInChatContext: Bool
        @AppStorage(\.enableSenseScopeByDefaultInChatContext)
        var enableSenseScopeByDefaultInChatContext: Bool
        @AppStorage(\.enableProjectScopeByDefaultInChatContext)
        var enableProjectScopeByDefaultInChatContext: Bool
        @AppStorage(\.enableWebScopeByDefaultInChatContext)
        var enableWebScopeByDefaultInChatContext: Bool
        @AppStorage(\.preferredChatModelIdForSenseScope)
        var preferredChatModelIdForSenseScope: String
        @AppStorage(\.preferredChatModelIdForProjectScope)
        var preferredChatModelIdForProjectScope: String
        @AppStorage(\.preferredChatModelIdForWebScope)
        var preferredChatModelIdForWebScope: String
        @AppStorage(\.chatModels) var chatModels
        @AppStorage(\.maxFocusedCodeLineCount)
        var maxFocusedCodeLineCount

        init() {}
    }

    @StateObject var settings = Settings()

    var body: some View {
        VStack {
            SubSection(
                title: Text("File Scope"),
                description: "Enable the bot to read the metadata of the editing file."
            ) {
                Form {
                    Toggle(isOn: $settings.enableFileScopeByDefaultInChatContext) {
                        Text("Enable by default")
                    }
                }
            }

            SubSection(
                title: Text("Code Scope"),
                description: "Enable the bot to read the code and metadata of the editing file."
            ) {
                Form {
                    Toggle(isOn: $settings.enableCodeScopeByDefaultInChatContext) {
                        Text("Enable by default")
                    }

                    HStack {
                        TextField(text: .init(get: {
                            "\(Int(settings.maxFocusedCodeLineCount))"
                        }, set: {
                            settings.maxFocusedCodeLineCount = Int($0) ?? 0
                        })) {
                            Text("Max focused code")
                        }
                        .textFieldStyle(.roundedBorder)

                        Text("lines")
                    }
                }
            }

            #if canImport(ProHostApp)

            SubSection(
                title: Text("Sense Scope (Experimental)"),
                description: IfFeatureEnabled(\.senseScopeInChat) {
                    Text("""
                    Enable the bot to access the relevant code \
                    of the editing document in the project, third party packages and the SDK.
                    """)
                } else: {
                    VStack(alignment: .leading) {
                        Text("""
                        Enable the bot to read the relevant code \
                        of the editing document in the SDK, and
                        """)

                        WithFeatureEnabled(\.senseScopeInChat, alignment: .inlineLeading) {
                            Text("the project and third party packages.")
                        }
                    }
                }
            ) {
                Form {
                    Toggle(isOn: $settings.enableSenseScopeByDefaultInChatContext) {
                        Text("Enable by default")
                    }
                    
                    let allModels = settings.chatModels + [.init(
                        id: "com.github.copilot",
                        name: "GitHub Copilot (poc)",
                        format: .openAI,
                        info: .init()
                    )]

                    Picker(
                        "Preferred chat model",
                        selection: $settings.preferredChatModelIdForSenseScope
                    ) {
                        Text("Use the default model").tag("")

                        if !allModels
                            .contains(where: {
                                $0.id == settings.preferredChatModelIdForSenseScope
                            }),
                            !settings.preferredChatModelIdForSenseScope.isEmpty
                        {
                            Text(
                                (allModels.first?.name).map { "\($0) (Default)" }
                                    ?? "No model found"
                            )
                            .tag(settings.preferredChatModelIdForSenseScope)
                        }

                        ForEach(allModels, id: \.id) { chatModel in
                            Text(chatModel.name).tag(chatModel.id)
                        }
                    }
                }
            }

            SubSection(
                title: Text("Project Scope (Experimental)"),
                description: IfFeatureEnabled(\.projectScopeInChat) {
                    Text("""
                    Enable the bot to search code and texts \
                    in the project, third party packages and the SDK.

                    The current implementation only performs keyword search.
                    """)
                } else: {
                    VStack(alignment: .leading) {
                        Text("""
                        Enable the bot to search code and texts \
                        in the neighboring files of the editing document, and
                        """)

                        WithFeatureEnabled(\.senseScopeInChat, alignment: .inlineLeading) {
                            Text("the project, third party packages and the SDK.")
                        }

                        Text("The current implementation only performs keyword search.")
                    }
                }
            ) {
                Form {
                    Toggle(isOn: $settings.enableProjectScopeByDefaultInChatContext) {
                        Text("Enable by default")
                    }
                    
                    let allModels = settings.chatModels + [.init(
                        id: "com.github.copilot",
                        name: "GitHub Copilot (poc)",
                        format: .openAI,
                        info: .init()
                    )]

                    Picker(
                        "Preferred chat model",
                        selection: $settings.preferredChatModelIdForProjectScope
                    ) {
                        Text("Use the default model").tag("")

                        if !allModels
                            .contains(where: {
                                $0.id == settings.preferredChatModelIdForProjectScope
                            }),
                            !settings.preferredChatModelIdForProjectScope.isEmpty
                        {
                            Text(
                                (allModels.first?.name).map { "\($0) (Default)" }
                                    ?? "No Model Found"
                            )
                            .tag(settings.preferredChatModelIdForProjectScope)
                        }

                        ForEach(allModels, id: \.id) { chatModel in
                            Text(chatModel.name).tag(chatModel.id)
                        }
                    }
                }
            }

            #endif

            SubSection(
                title: Text("Web Scope"),
                description: "Allow the bot to search on Bing or read a web page. The current implementation requires function calling."
            ) {
                Form {
                    Toggle(isOn: $settings.enableWebScopeByDefaultInChatContext) {
                        Text("Enable @web scope by default in chat context.")
                    }
                    
                    let allModels = settings.chatModels + [.init(
                        id: "com.github.copilot",
                        name: "GitHub Copilot (poc)",
                        format: .openAI,
                        info: .init()
                    )]

                    Picker(
                        "Preferred chat model",
                        selection: $settings.preferredChatModelIdForWebScope
                    ) {
                        Text("Use the default model").tag("")

                        if !allModels
                            .contains(where: {
                                $0.id == settings.preferredChatModelIdForWebScope
                            }),
                            !settings.preferredChatModelIdForWebScope.isEmpty
                        {
                            Text(
                                (allModels.first?.name).map { "\($0) (Default)" }
                                    ?? "No model found"
                            )
                            .tag(settings.preferredChatModelIdForWebScope)
                        }

                        ForEach(allModels, id: \.id) { chatModel in
                            Text(chatModel.name).tag(chatModel.id)
                        }
                    }
                }
            }
        }
    }
}


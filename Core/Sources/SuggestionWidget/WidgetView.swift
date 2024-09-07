import ActiveApplicationMonitor
import ComposableArchitecture
import Preferences
import SuggestionBasic
import SwiftUI

struct WidgetView: View {
    let store: StoreOf<CircularWidget>
    @State var isHovering: Bool = false
    var onOpenChatClicked: () -> Void = {}
    var onCustomCommandClicked: (CustomCommand) -> Void = { _ in }

    @AppStorage(\.hideCircularWidget) var hideCircularWidget

    var body: some View {
        WithPerceptionTracking {
            Circle()
                .fill(isHovering ? .white.opacity(0.5) : .white.opacity(0.15))
                .onTapGesture {
                    store.send(.widgetClicked, animation: .easeInOut(duration: 0.2))
                }
                .overlay { WidgetAnimatedCircle(store: store) }
                .onHover { yes in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = yes
                    }
                }.contextMenu {
                    WidgetContextMenu(store: store)
                }
                .opacity({
                    if !hideCircularWidget { return 1 }
                    return store.isProcessing ? 1 : 0
                }())
                .animation(
                    featureFlag: \.animationCCrashSuggestion,
                    .easeInOut(duration: 0.2),
                    value: store.isProcessing
                )
        }
    }
}

struct WidgetAnimatedCircle: View {
    let store: StoreOf<CircularWidget>
    @State var processingProgress: Double = 0

    struct OverlayCircleState: Equatable {
        var isProcessing: Bool
        var isContentEmpty: Bool
    }

    var body: some View {
        WithPerceptionTracking {
            let minimumLineWidth: Double = 3
            let lineWidth = (1 - processingProgress) *
                (Style.widgetWidth - minimumLineWidth / 2) + minimumLineWidth
            let scale = max(processingProgress * 1, 0.0001)
            ZStack {
                Circle()
                    .stroke(
                        Color(nsColor: .darkGray),
                        style: .init(lineWidth: minimumLineWidth)
                    )
                    .padding(minimumLineWidth / 2)

                // how do I stop the repeatForever animation without removing the view?
                // I tried many solutions found on stackoverflow but non of them works.
                Group {
                    if store.isProcessing {
                        Circle()
                            .stroke(
                                Color.accentColor,
                                style: .init(lineWidth: lineWidth)
                            )
                            .padding(minimumLineWidth / 2)
                            .scaleEffect(x: scale, y: scale)
                            .opacity(
                                !store.isContentEmpty || store.isProcessing ? 1 : 0
                            )
                            .animation(
                                featureFlag: \.animationCCrashSuggestion,
                                .easeInOut(duration: 1)
                                    .repeatForever(autoreverses: true),
                                value: processingProgress
                            )
                    } else {
                        Circle()
                            .stroke(
                                Color.accentColor,
                                style: .init(lineWidth: lineWidth)
                            )
                            .padding(minimumLineWidth / 2)
                            .scaleEffect(x: scale, y: scale)
                            .opacity(
                                !store.isContentEmpty || store.isProcessing ? 1 : 0
                            )
                            .animation(
                                featureFlag: \.animationCCrashSuggestion,
                                .easeInOut(duration: 1),
                                value: processingProgress
                            )
                    }
                }
                .onChange(of: store.isProcessing) { _ in
                    refreshRing(
                        isProcessing: store.isProcessing,
                        isContentEmpty: store.isContentEmpty
                    )
                }
                .onChange(of: store.isContentEmpty) { _ in
                    refreshRing(
                        isProcessing: store.isProcessing,
                        isContentEmpty: store.isContentEmpty
                    )
                }
            }
        }
    }

    func refreshRing(isProcessing: Bool, isContentEmpty: Bool) {
        if isProcessing {
            processingProgress = 1 - processingProgress
        } else {
            processingProgress = isContentEmpty ? 0 : 1
        }
    }
}

struct WidgetContextMenu: View {
    @AppStorage(\.useGlobalChat) var useGlobalChat
    @AppStorage(\.realtimeSuggestionToggle) var realtimeSuggestionToggle
    @AppStorage(\.disableSuggestionFeatureGlobally) var disableSuggestionFeatureGlobally
    @AppStorage(\.suggestionFeatureEnabledProjectList) var suggestionFeatureEnabledProjectList
    @AppStorage(\.suggestionFeatureDisabledLanguageList) var suggestionFeatureDisabledLanguageList
    @AppStorage(\.customCommands) var customCommands
    let store: StoreOf<CircularWidget>

    @Dependency(\.xcodeInspector) var xcodeInspector

    var body: some View {
        WithPerceptionTracking {
            Group { // Commands
                if !store.isChatOpen {
                    Button(action: {
                        store.send(.openChatButtonClicked)
                    }) {
                        Text("Open Chat")
                    }
                }

                customCommandMenu()
            }

            Divider()

            Group {
                enableSuggestionForProject

                disableSuggestionForLanguage
            }

            Divider()

            Group { // Settings
                Button(action: {
                    store.send(.detachChatPanelToggleClicked)
                }) {
                    Text("Detach Chat Panel")
                    if store.isChatPanelDetached {
                        Image(systemName: "checkmark")
                    }
                }

                Button(action: {
                    realtimeSuggestionToggle.toggle()
                }) {
                    Text("Realtime Suggestion")
                    if realtimeSuggestionToggle {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()
        }
    }

    func customCommandMenu() -> some View {
        Menu("Custom Commands") {
            ForEach(customCommands, id: \.name) { command in
                Button(action: {
                    store.send(.runCustomCommandButtonClicked(command))
                }) {
                    Text(command.name)
                }
            }
        }
    }
}

extension WidgetContextMenu {
    @ViewBuilder
    var enableSuggestionForProject: some View {
        if let projectPath = xcodeInspector.activeProjectRootURL?.path,
           disableSuggestionFeatureGlobally
        {
            let matchedPath = suggestionFeatureEnabledProjectList.first { path in
                projectPath.hasPrefix(path)
            }
            Button(action: {
                if matchedPath != nil {
                    suggestionFeatureEnabledProjectList
                        .removeAll { path in path == matchedPath }
                } else {
                    suggestionFeatureEnabledProjectList.append(projectPath)
                }
            }) {
                if matchedPath == nil {
                    Text("Add to Suggestion-Enabled Project List")
                } else {
                    Text("Remove from Suggestion-Enabled Project List")
                }
            }
        }
    }

    @ViewBuilder
    var disableSuggestionForLanguage: some View {
        let fileURL = xcodeInspector.activeDocumentURL
        let fileLanguage = fileURL.map(languageIdentifierFromFileURL) ?? .plaintext
        let matched = suggestionFeatureDisabledLanguageList.first { rawValue in
            fileLanguage.rawValue == rawValue
        }
        Button(action: {
            if let matched {
                suggestionFeatureDisabledLanguageList.removeAll { $0 == matched }
            } else {
                suggestionFeatureDisabledLanguageList.append(fileLanguage.rawValue)
            }
        }) {
            if matched == nil {
                Text("Disable Suggestion for \"\(fileLanguage.rawValue.capitalized)\"")
            } else {
                Text("Enable Suggestion for \"\(fileLanguage.rawValue.capitalized)\"")
            }
        }
    }
}

struct WidgetView_Preview: PreviewProvider {
    static var previews: some View {
        VStack {
            WidgetView(
                store: Store(
                    initialState: .init(
                        isProcessing: false,
                        isDisplayingContent: false,
                        isContentEmpty: true,
                        isChatPanelDetached: false,
                        isChatOpen: false
                    ),
                    reducer: { CircularWidget() }
                ),
                isHovering: false
            )

            WidgetView(
                store: Store(
                    initialState: .init(
                        isProcessing: false,
                        isDisplayingContent: false,
                        isContentEmpty: true,
                        isChatPanelDetached: false,
                        isChatOpen: false
                    ),
                    reducer: { CircularWidget() }
                ),
                isHovering: true
            )

            WidgetView(
                store: Store(
                    initialState: .init(
                        isProcessing: true,
                        isDisplayingContent: false,
                        isContentEmpty: true,
                        isChatPanelDetached: false,
                        isChatOpen: false
                    ),
                    reducer: { CircularWidget() }
                ),
                isHovering: false
            )

            WidgetView(
                store: Store(
                    initialState: .init(
                        isProcessing: false,
                        isDisplayingContent: true,
                        isContentEmpty: true,
                        isChatPanelDetached: false,
                        isChatOpen: false
                    ),
                    reducer: { CircularWidget() }
                ),
                isHovering: false
            )
        }
        .frame(width: 30)
        .background(Color.black)
    }
}


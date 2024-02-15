import ActiveApplicationMonitor
import ComposableArchitecture
import Preferences
import SuggestionModel
import SwiftUI

struct WidgetView: View {
    let store: StoreOf<CircularWidgetFeature>
    @State var isHovering: Bool = false
    var onOpenChatClicked: () -> Void = {}
    var onCustomCommandClicked: (CustomCommand) -> Void = { _ in }

    @AppStorage(\.hideCircularWidget) var hideCircularWidget

    var body: some View {
        WithViewStore(store, observe: { $0.isProcessing }) { viewStore in
            Circle()
                .fill(isHovering ? .white.opacity(0.5) : .white.opacity(0.15))
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.send(.widgetClicked)
                    }
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
                    return viewStore.state ? 1 : 0
                }())
                .animation(
                    featureFlag: \.animationCCrashSuggestion,
                    .easeInOut(duration: 0.2),
                    value: viewStore.state
                )
        }
    }
}

struct WidgetAnimatedCircle: View {
    let store: StoreOf<CircularWidgetFeature>
    @State var processingProgress: Double = 0

    struct OverlayCircleState: Equatable {
        var isProcessing: Bool
        var isContentEmpty: Bool
    }

    var body: some View {
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
            WithViewStore(
                store,
                observe: {
                    OverlayCircleState(
                        isProcessing: $0.isProcessing,
                        isContentEmpty: $0.isContentEmpty
                    )
                }
            ) { viewStore in
                Group {
                    if viewStore.isProcessing {
                        Circle()
                            .stroke(
                                Color.accentColor,
                                style: .init(lineWidth: lineWidth)
                            )
                            .padding(minimumLineWidth / 2)
                            .scaleEffect(x: scale, y: scale)
                            .opacity(
                                !viewStore.isContentEmpty || viewStore.isProcessing ? 1 : 0
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
                                !viewStore.isContentEmpty || viewStore
                                    .isProcessing ? 1 : 0
                            )
                            .animation(
                                featureFlag: \.animationCCrashSuggestion,
                                .easeInOut(duration: 1),
                                value: processingProgress
                            )
                    }
                }
                .onChange(of: viewStore.isProcessing) { _ in
                    refreshRing(
                        isProcessing: viewStore.state.isProcessing,
                        isContentEmpty: viewStore.state.isContentEmpty
                    )
                }
                .onChange(of: viewStore.isContentEmpty) { _ in
                    refreshRing(
                        isProcessing: viewStore.state.isProcessing,
                        isContentEmpty: viewStore.state.isContentEmpty
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
    @AppStorage(\.hideCommonPrecedingSpacesInSuggestion) var hideCommonPrecedingSpacesInSuggestion
    @AppStorage(\.disableSuggestionFeatureGlobally) var disableSuggestionFeatureGlobally
    @AppStorage(\.suggestionFeatureEnabledProjectList) var suggestionFeatureEnabledProjectList
    @AppStorage(\.suggestionFeatureDisabledLanguageList) var suggestionFeatureDisabledLanguageList
    @AppStorage(\.customCommands) var customCommands
    let store: StoreOf<CircularWidgetFeature>

    @Dependency(\.xcodeInspector) var xcodeInspector

    var body: some View {
        Group {
            Group { // Commands
                WithViewStore(store, observe: { $0.isChatOpen }) { viewStore in
                    if !viewStore.state {
                        Button(action: {
                            viewStore.send(.openChatButtonClicked)
                        }) {
                            Text("Open Chat")
                        }
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
                WithViewStore(
                    store,
                    observe: { $0.isChatPanelDetached }
                ) { viewStore in
                    Button(action: {
                        viewStore.send(.detachChatPanelToggleClicked)
                    }) {
                        Text("Detach Chat Panel")
                        if viewStore.state {
                            Image(systemName: "checkmark")
                        }
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

                Button(action: {
                    hideCommonPrecedingSpacesInSuggestion.toggle()
                }, label: {
                    Text("Hide Common Preceding Spaces in Suggestion")
                    if hideCommonPrecedingSpacesInSuggestion {
                        Image(systemName: "checkmark")
                    }
                })
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
        WithViewStore(store) { _ in
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
    }

    @ViewBuilder
    var disableSuggestionForLanguage: some View {
        WithViewStore(store) { _ in
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
                    reducer: CircularWidgetFeature()
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
                    reducer: CircularWidgetFeature()
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
                    reducer: CircularWidgetFeature()
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
                    reducer: CircularWidgetFeature()
                ),
                isHovering: false
            )
        }
        .frame(width: 30)
        .background(Color.black)
    }
}


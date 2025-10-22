import ActiveApplicationMonitor
import ComposableArchitecture
import Preferences
import SharedUIComponents
import SuggestionBasic
import SwiftUI

struct WidgetView: View {
    let store: StoreOf<CircularWidget>
    @State var isHovering: Bool = false
    var onOpenChatClicked: () -> Void = {}
    var onCustomCommandClicked: (CustomCommand) -> Void = { _ in }

    @AppStorage(\.hideCircularWidget) var hideCircularWidget

    var body: some View {
        GeometryReader { _ in
            WithPerceptionTracking {
                ZStack {
                    WidgetAnimatedCapsule(
                        store: store,
                        isHovering: isHovering
                    )
                }
                .onTapGesture {
                    store.send(.widgetClicked, animation: .easeInOut(duration: 0.2))
                }
                .onHover { yes in
                    withAnimation(.easeInOut(duration: 0.14)) {
                        isHovering = yes
                    }
                }
                .contextMenu {
                    WidgetContextMenu(store: store)
                }
                .opacity({
                    if !hideCircularWidget { return 1 }
                    return store.isProcessing ? 1 : 0
                }())
                .animation(
                    .easeInOut(duration: 0.2),
                    value: isHovering
                )
                .animation(
                    .easeInOut(duration: 0.2),
                    value: store.isProcessing
                )
            }
        }
    }
}

struct WidgetAnimatedCapsule: View {
    let store: StoreOf<CircularWidget>
    var isHovering: Bool

    @State private var animatedProgress: CGFloat = 0 // 0~1
    @State private var animationTask: Task<Void, Never>?

    private let movingSegmentLength: CGFloat = 0.28

    var body: some View {
        GeometryReader { geo in
            WithPerceptionTracking {
                let capsuleWidth = geo.size.width
                let capsuleHeight = geo.size.height

                let backgroundWidth = capsuleWidth
                let foregroundWidth = max(capsuleWidth - 4, 2)
                let padding = (backgroundWidth - foregroundWidth) / 2

                ZStack {
                    Capsule()
                        .modify {
                            if #available(macOS 26.0, *) {
                                $0.glassEffect()
                            } else if #available(macOS 13.0, *) {
                                $0.backgroundStyle(.thickMaterial.opacity(0.8)).overlay(
                                    Capsule().stroke(
                                        Color(nsColor: .darkGray).opacity(0.2),
                                        lineWidth: 1
                                    )
                                )
                            } else {
                                $0.fill(Color(nsColor: .darkGray).opacity(0.6)).overlay(
                                    Capsule().stroke(
                                        Color(nsColor: .darkGray).opacity(0.2),
                                        lineWidth: 1
                                    )
                                )
                            }
                        }
                        .frame(width: backgroundWidth, height: capsuleHeight)
                        .animation(.easeInOut(duration: 0.14), value: isHovering)

                    Capsule()
                        .fill(Color.accentColor.opacity(0.8))
                        .frame(
                            width: foregroundWidth,
                            height: capsuleHeight * movingSegmentLength
                        )
                        .opacity(store.isProcessing ? 1 : 0)
                        .position(
                            x: capsuleWidth / 2,
                            y: {
                                let height = capsuleHeight - padding * 2
                                let base = padding
                                return base + height * (normalizedStart() + movingSegmentLength / 2)
                            }()
                        )
                        .animation(nil, value: store.isProcessing)
                        .animation(.easeInOut(duration: 0.14), value: isHovering)
                }
                .onAppear {
                    updateAnimationTask(isProcessing: store.isProcessing)
                }
                .onChange(of: store.isProcessing) { newValue in
                    updateAnimationTask(isProcessing: newValue)
                }
                .onChange(of: store.isContentEmpty) { _ in
                    if !store.isProcessing {
                        animatedProgress = store.isContentEmpty ? 0 : 1
                    }
                }
                .onChange(of: isHovering) { _ in }
            }
        }
    }

    // 进度条起点
    private func normalizedStart() -> CGFloat {
        let p = max(0, min(1, animatedProgress))
        return p * (1 - movingSegmentLength)
    }

    // 动画任务
    private func updateAnimationTask(isProcessing: Bool) {
        animationTask?.cancel()
        animationTask = nil

        if isProcessing {
            animationTask = Task { [weak store] in
                await MainActor.run {
                    animatedProgress = 0
                }
                while !Task.isCancelled {
                    await MainActor.run {
                        withAnimation(.linear(duration: 1.2)) {
                            animatedProgress = 1
                        }
                    }
                    try? await Task.sleep(nanoseconds: UInt64(1.2 * 1_000_000_000))
                    if Task.isCancelled { break }
                    if !(store?.isProcessing ?? true) { break }
                    await MainActor.run {
                        withAnimation(.linear(duration: 1.2)) {
                            animatedProgress = 0
                        }
                    }
                    try? await Task.sleep(nanoseconds: UInt64(1.2 * 1_000_000_000))
                    if Task.isCancelled { break }
                    if !(store?.isProcessing ?? true) { break }
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                animatedProgress = store.isContentEmpty ? 0 : 1
            }
        }
    }
}

// 下面的WidgetContextMenu和其它内容保持不变喵～

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
                Button(action: {
                    store.send(.openChatButtonClicked)
                }) {
                    Text("Open Chat")
                }

                Button(action: {
                    store.send(.openModificationButtonClicked)
                }) {
                    Text("Write or Modify Code")
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
            .frame(width: Style.widgetWidth, height: Style.widgetHeight)

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
            .frame(width: Style.widgetWidth, height: Style.widgetHeight)

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
            .frame(width: Style.widgetWidth, height: Style.widgetHeight)

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
            .frame(width: Style.widgetWidth, height: Style.widgetHeight)
        }
        .frame(width: 200, height: 200)
        .background(Color.black)
    }
}


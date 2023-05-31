import ActiveApplicationMonitor
import Environment
import Preferences
import SuggestionModel
import SwiftUI

@MainActor
final class WidgetViewModel: ObservableObject {
    struct IsProcessingCounter {
        var expirationDate: TimeInterval
    }

    private var isProcessingCounters = [IsProcessingCounter]()
    private var cleanupIsProcessingCounterTask: Task<Void, Error>?
    @Published var isProcessing: Bool
    @Published var currentFileURL: URL?

    func markIsProcessing(date: Date = Date()) {
        let deadline = date.timeIntervalSince1970 + 20
        isProcessingCounters.append(IsProcessingCounter(expirationDate: deadline))
        isProcessing = true
        
        cleanupIsProcessingCounterTask?.cancel()
        cleanupIsProcessingCounterTask = Task { [weak self] in
            try await Task.sleep(nanoseconds: 20 * 1_000_000_000)
            try Task.checkCancellation()
            Task { @MainActor [weak self] in
                guard let self else { return }
                isProcessingCounters.removeAll()
                isProcessing = false
            }
        }
    }

    func endIsProcessing(date: Date = Date()) {
        if !isProcessingCounters.isEmpty {
            isProcessingCounters.removeFirst()
        }
        isProcessingCounters.removeAll(where: { $0.expirationDate < date.timeIntervalSince1970 })
        isProcessing = !isProcessingCounters.isEmpty
    }

    init(isProcessing: Bool = false) {
        self.isProcessing = isProcessing
    }
}

struct WidgetView: View {
    @ObservedObject var viewModel: WidgetViewModel
    @ObservedObject var panelViewModel: SuggestionPanelViewModel
    @ObservedObject var chatWindowViewModel: ChatWindowViewModel
    @State var isHovering: Bool = false
    @State var processingProgress: Double = 0
    var onOpenChatClicked: () -> Void = {}
    var onCustomCommandClicked: (CustomCommand) -> Void = { _ in }

    var body: some View {
        Circle().fill(isHovering ? .white.opacity(0.8) : .white.opacity(0.3))
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    let wasDisplayed = {
                        if panelViewModel.isPanelDisplayed,
                           panelViewModel.content != nil { return true }
                        if chatWindowViewModel.isPanelDisplayed,
                           chatWindowViewModel.chat != nil { return true }
                        return false
                    }()
                    panelViewModel.isPanelDisplayed = !wasDisplayed
                    chatWindowViewModel.isPanelDisplayed = !wasDisplayed
                    let isDisplayed = !wasDisplayed

                    if !isDisplayed {
                        if let app = ActiveApplicationMonitor.previousActiveApplication,
                           app.isXcode
                        {
                            app.activate()
                        }
                    }
                }
            }
            .overlay {
                let minimumLineWidth: Double = 3
                let lineWidth = (1 - processingProgress) *
                    (Style.widgetWidth - minimumLineWidth / 2) + minimumLineWidth
                let scale = max(processingProgress * 1, 0.0001)
                let empty = panelViewModel.content == nil && chatWindowViewModel.chat == nil

                ZStack {
                    Circle()
                        .stroke(
                            Color(nsColor: .darkGray),
                            style: .init(lineWidth: minimumLineWidth)
                        )
                        .padding(minimumLineWidth / 2)

                    // how do I stop the repeatForever animation without removing the view?
                    // I tried many solutions found on stackoverflow but non of them works.
                    if viewModel.isProcessing {
                        Circle()
                            .stroke(
                                Color.accentColor,
                                style: .init(lineWidth: lineWidth)
                            )
                            .padding(minimumLineWidth / 2)
                            .scaleEffect(x: scale, y: scale)
                            .opacity(!empty || viewModel.isProcessing ? 1 : 0)
                            .animation(
                                .easeInOut(duration: 1).repeatForever(autoreverses: true),
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
                            .opacity(!empty || viewModel.isProcessing ? 1 : 0)
                            .animation(.easeInOut(duration: 1), value: processingProgress)
                    }
                }
            }
            .onChange(of: viewModel.isProcessing) { _ in refreshRing() }
            .onChange(of: panelViewModel.content?.contentHash) { _ in refreshRing() }
            .onChange(of: chatWindowViewModel.chat?.id) { _ in refreshRing() }
            .onHover { yes in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = yes
                }
            }.contextMenu {
                WidgetContextMenu(
                    chatWindowViewModel: chatWindowViewModel,
                    widgetViewModel: viewModel,
                    isChatOpen: chatWindowViewModel.isPanelDisplayed
                        && chatWindowViewModel.chat != nil,
                    onOpenChatClicked: onOpenChatClicked,
                    onCustomCommandClicked: onCustomCommandClicked
                )
            }
    }

    func refreshRing() {
        Task {
            await Task.yield()
            if viewModel.isProcessing {
                processingProgress = 1 - processingProgress
            } else {
                let empty = panelViewModel.content == nil && chatWindowViewModel.chat == nil
                processingProgress = empty ? 0 : 1
            }
        }
    }
}

struct WidgetContextMenu: View {
    @AppStorage(\.useGlobalChat) var useGlobalChat
    @AppStorage(\.realtimeSuggestionToggle) var realtimeSuggestionToggle
    @AppStorage(\.acceptSuggestionWithAccessibilityAPI) var acceptSuggestionWithAccessibilityAPI
    @AppStorage(\.hideCommonPrecedingSpacesInSuggestion) var hideCommonPrecedingSpacesInSuggestion
    @AppStorage(\.disableSuggestionFeatureGlobally) var disableSuggestionFeatureGlobally
    @AppStorage(\.suggestionFeatureEnabledProjectList) var suggestionFeatureEnabledProjectList
    @AppStorage(\.suggestionFeatureDisabledLanguageList) var suggestionFeatureDisabledLanguageList
    @AppStorage(\.customCommands) var customCommands
    @ObservedObject var chatWindowViewModel: ChatWindowViewModel
    @ObservedObject var widgetViewModel: WidgetViewModel
    @State var projectPath: String?
    @State var fileURL: URL?
    var isChatOpen: Bool
    var onOpenChatClicked: () -> Void = {}
    var onCustomCommandClicked: (CustomCommand) -> Void = { _ in }

    var body: some View {
        Group {
            Group { // Commands
                if !isChatOpen {
                    Button(action: {
                        onOpenChatClicked()
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
                    chatWindowViewModel.chatPanelInASeparateWindow.toggle()
                }) {
                    Text("Detach Chat Panel")
                    if chatWindowViewModel.chatPanelInASeparateWindow {
                        Image(systemName: "checkmark")
                    }
                }

                Button(action: {
                    useGlobalChat.toggle()
                }) {
                    Text("Use Shared Conversation")
                    if useGlobalChat {
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

                Button(action: {
                    acceptSuggestionWithAccessibilityAPI.toggle()
                }, label: {
                    Text("Accept Suggestion with Accessibility API")
                    if acceptSuggestionWithAccessibilityAPI {
                        Image(systemName: "checkmark")
                    }
                })

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
        .onAppear {
            updateProjectPath(fileURL: widgetViewModel.currentFileURL)
        }
        .onChange(of: widgetViewModel.currentFileURL) { fileURL in
            updateProjectPath(fileURL: fileURL)
        }
    }

    func updateProjectPath(fileURL: URL?) {
        Task {
            let projectURL: URL? = await {
                if let url = try? await Environment.fetchCurrentProjectRootURLFromXcode() {
                    return url
                }
                guard let fileURL else { return nil }
                return try? await Environment.guessProjectRootURLForFile(fileURL)
            }()
            if let projectURL {
                Task { @MainActor in
                    self.fileURL = fileURL
                    self.projectPath = projectURL.path
                }
            }
        }
    }

    func customCommandMenu() -> some View {
        Menu("Custom Commands") {
            ForEach(customCommands, id: \.name) { command in
                Button(action: {
                    onCustomCommandClicked(command)
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
        if let projectPath, disableSuggestionFeatureGlobally {
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
        if let fileURL {
            let fileLanguage = languageIdentifierFromFileURL(fileURL)
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
                viewModel: .init(isProcessing: false),
                panelViewModel: .init(),
                chatWindowViewModel: .init(),
                isHovering: false
            )

            WidgetView(
                viewModel: .init(isProcessing: false),
                panelViewModel: .init(),
                chatWindowViewModel: .init(),
                isHovering: true
            )

            WidgetView(
                viewModel: .init(isProcessing: true),
                panelViewModel: .init(),
                chatWindowViewModel: .init(),
                isHovering: false
            )

            WidgetView(
                viewModel: .init(isProcessing: false),
                panelViewModel: .init(
                    content: .suggestion(SuggestionProvider(
                        code: "Hello",
                        startLineIndex: 0,
                        suggestionCount: 0,
                        currentSuggestionIndex: 0
                    ))
                ),
                chatWindowViewModel: .init(),
                isHovering: false
            )
        }
        .frame(width: 30)
        .background(Color.black)
    }
}


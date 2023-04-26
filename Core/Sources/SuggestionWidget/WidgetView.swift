import Environment
import Preferences
import SwiftUI

@MainActor
final class WidgetViewModel: ObservableObject {
    @Published var isProcessing: Bool
    @Published var currentFileURL: URL?

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
                    panelViewModel.isPanelDisplayed.toggle()
                    chatWindowViewModel.isPanelDisplayed = panelViewModel.isPanelDisplayed
                }
            }
            .overlay {
                let minimumLineWidth: Double = 4
                let lineWidth = (1 - processingProgress) * 28 + minimumLineWidth
                let scale = max(processingProgress * 1, 0.0001)
                let empty = panelViewModel.content == nil && panelViewModel.chat == nil

                ZStack {
                    Circle()
                        .stroke(
                            Color(nsColor: .darkGray),
                            style: .init(lineWidth: minimumLineWidth)
                        )
                        .padding(2)

                    // how do I stop the repeatForever animation without removing the view?
                    // I tried many solutions found on stackoverflow but non of them works.
                    if viewModel.isProcessing {
                        Circle()
                            .stroke(
                                Color.accentColor,
                                style: .init(lineWidth: lineWidth)
                            )
                            .padding(2)
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
                            .padding(2)
                            .scaleEffect(x: scale, y: scale)
                            .opacity(!empty || viewModel.isProcessing ? 1 : 0)
                            .animation(.easeInOut(duration: 1), value: processingProgress)
                    }
                }
            }
            .onChange(of: viewModel.isProcessing) { _ in refreshRing() }
            .onChange(of: panelViewModel.content?.contentHash) { _ in refreshRing() }
            .onHover { yes in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = yes
                }
            }.contextMenu {
                WidgetContextMenu(
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
                let empty = panelViewModel.content == nil && panelViewModel.chat == nil
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
    @AppStorage(\.forceOrderWidgetToFront) var forceOrderWidgetToFront
    @AppStorage(\.disableSuggestionFeatureGlobally) var disableSuggestionFeatureGlobally
    @AppStorage(\.suggestionFeatureEnabledProjectList) var suggestionFeatureEnabledProjectList
    @AppStorage(\.customCommands) var customCommands
    @AppStorage(\.chatPanelInASeparateWindow) var chatPanelInASeparateWindow
    @ObservedObject var widgetViewModel: WidgetViewModel
    @State var projectPath: String?
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

            Group { // Settings
                Button(action: {
                    chatPanelInASeparateWindow.toggle()
                }) {
                    Text("Detach Chat Panel")
                    if chatPanelInASeparateWindow {
                        Image(systemName: "checkmark")
                    }
                }

                Button(action: {
                    useGlobalChat.toggle()
                }) {
                    Text("Use Global Chat")
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

                Button(action: {
                    forceOrderWidgetToFront.toggle()
                }, label: {
                    Text("Force Order Widget to Front")
                    if forceOrderWidgetToFront {
                        Image(systemName: "checkmark")
                    }
                })

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

            Divider()

            Button(action: {
                exit(0)
            }) {
                Text("Quit")
            }
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
            let projectURL = try? await Environment.fetchCurrentProjectRootURL(fileURL)
            if let projectURL {
                Task { @MainActor in
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

import Environment
import SwiftUI

@MainActor
final class SuggestionPanelViewModel: ObservableObject {
    enum Content {
        case suggestion(SuggestionProvider)
        case error(String)

        var contentHash: String {
            switch self {
            case let .error(e):
                return "error: \(e)"
            case let .suggestion(provider):
                return "suggestion: \(provider.code.hashValue)"
            }
        }
    }

    enum ActiveTab {
        case suggestion
        case chat
    }

    @Published var content: Content? {
        didSet {
            adjustActiveTabAndShowHideIfNeeded(tab: .suggestion)
        }
    }

    @Published var chat: ChatProvider? {
        didSet {
            adjustActiveTabAndShowHideIfNeeded(tab: .chat)
        }
    }

    @Published var activeTab: ActiveTab {
        didSet {
            onActiveTabChanged?(activeTab)
        }
    }

    @Published var isPanelDisplayed: Bool
    @Published var alignTopToAnchor = false
    @Published var colorScheme: ColorScheme

    var onActiveTabChanged: ((ActiveTab) -> Void)?

    public init(
        content: Content? = nil,
        chat: ChatProvider? = nil,
        isPanelDisplayed: Bool = false,
        activeTab: ActiveTab = .suggestion,
        colorScheme: ColorScheme = .dark,
        onActiveTabChanged: ((ActiveTab) -> Void)? = nil
    ) {
        self.content = content
        self.chat = chat
        self.isPanelDisplayed = isPanelDisplayed
        self.activeTab = activeTab
        self.colorScheme = colorScheme
        self.onActiveTabChanged = onActiveTabChanged
    }

    func adjustActiveTabAndShowHideIfNeeded(tab: ActiveTab) {
        switch tab {
        case .suggestion:
            if content != nil {
                activeTab = .suggestion
                isPanelDisplayed = true
                return
            }
        case .chat:
            if chat != nil {
                activeTab = .chat
                isPanelDisplayed = true
                return
            }
        }

        if content != nil {
            activeTab = .suggestion
            return
        }

        if chat != nil {
            activeTab = .chat
            return
        }

        activeTab = .suggestion
        isPanelDisplayed = false
    }
}

struct SuggestionPanelView: View {
    @ObservedObject var viewModel: SuggestionPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.alignTopToAnchor {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            VStack {
                if let content = viewModel.content {
                    if case .suggestion = viewModel.activeTab {
                        ZStack(alignment: .topLeading) {
                            switch content {
                            case let .suggestion(suggestion):
                                CodeBlockSuggestionPanel(suggestion: suggestion)
                            case let .error(description):
                                ErrorPanel(viewModel: viewModel, description: description)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: Style.panelHeight)
                        .fixedSize(horizontal: false, vertical: true)
                        .allowsHitTesting(viewModel.isPanelDisplayed)
                        .preferredColorScheme(viewModel.colorScheme)
                    }
                }

                if let chat = viewModel.chat {
                    if case .chat = viewModel.activeTab {
                        ChatPanel(chat: chat)
                            .frame(maxWidth: .infinity, maxHeight: Style.panelHeight)
                            .fixedSize(horizontal: false, vertical: true)
                            .allowsHitTesting(viewModel.isPanelDisplayed)
                            .preferredColorScheme(viewModel.colorScheme)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if viewModel.alignTopToAnchor {
                Spacer()
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
        .opacity({
            guard viewModel.isPanelDisplayed else { return 0 }
            guard viewModel.content != nil || viewModel.chat != nil else { return 0 }
            return 1
        }())
        .animation(.easeInOut(duration: 0.2), value: viewModel.content?.contentHash)
        .animation(.easeInOut(duration: 0.2), value: viewModel.activeTab)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isPanelDisplayed)
        .frame(maxWidth: Style.panelWidth, maxHeight: Style.panelHeight)
    }
}

struct CommandButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(configuration.isPressed ? 0.8 : 1))
                    .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
            }
    }
}

// MARK: - Previews

struct SuggestionPanelView_Error_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            content: .error("This is an error\nerror"),
            isPanelDisplayed: true
        ))
        .frame(width: 450, height: 200)
    }
}

struct SuggestionPanelView_Chat_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            chat: .init(
                history: [
                    .init(id: "1", isUser: true, text: "Hello"),
                    .init(id: "2", isUser: false, text: "Hi"),
                    .init(id: "3", isUser: true, text: "What's up?"),
                ]
            ),
            isPanelDisplayed: true,
            activeTab: .chat
        ))
        .frame(width: 450, height: 300)
    }
}

struct SuggestionPanelView_Both_DisplayingChat_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            content: .suggestion(SuggestionProvider(
                code: """
                - (void)addSubview:(UIView *)view {
                    [self addSubview:view];
                }
                """,
                language: "objective-c",
                startLineIndex: 8,
                suggestionCount: 2,
                currentSuggestionIndex: 0
            )),
            chat: .init(
                history: [
                    .init(id: "1", isUser: true, text: "Hello"),
                    .init(id: "2", isUser: false, text: "Hi"),
                    .init(id: "3", isUser: true, text: "What's up?"),
                ]
            ),
            isPanelDisplayed: true,
            activeTab: .chat,
            colorScheme: .light
        ))
        .frame(width: 450, height: 500)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

struct SuggestionPanelView_Both_DisplayingSuggestion_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionPanelView(viewModel: .init(
            content: .suggestion(SuggestionProvider(
                code: """
                - (void)addSubview:(UIView *)view {
                    [self addSubview:view];
                }
                """,
                language: "objective-c",
                startLineIndex: 8,
                suggestionCount: 2,
                currentSuggestionIndex: 0
            )),
            chat: .init(
                history: [
                    .init(id: "1", isUser: true, text: "Hello"),
                    .init(id: "2", isUser: false, text: "Hi"),
                    .init(id: "3", isUser: true, text: "What's up?"),
                ]
            ),
            isPanelDisplayed: true,
            activeTab: .suggestion,
            colorScheme: .dark
        ))
        .frame(width: 450, height: 200)
        .background {
            HStack {
                Color.red
                Color.green
                Color.blue
            }
        }
    }
}

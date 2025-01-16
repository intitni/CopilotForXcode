import Combine
import CommandHandler
import Dependencies
import IdentifiedCollections
import Perception
import SharedUIComponents
import SuggestionBasic
import SwiftUI
import Workspace
import WorkspaceSuggestionService
import XcodeInspector

@Perceptible
public class PresentingCodeSuggestionManager {
    let filespace: Filespace
    var suggestionManager: FileSuggestionManager? {
        filespace.plugin(for: FileSuggestionManagerPlugin.self)?.suggestionManager
    }

    var displaySuggestions: FileSuggestionManager.CircularSuggestionList {
        suggestionManager?.displaySuggestions ?? .empty
    }

    init(filespace: Filespace) {
        self.filespace = filespace
    }

    func nextSuggestionInGroup(index: Int) {
        suggestionManager?.nextSuggestionInGroup(index: index)
    }

    func previousSuggestionInGroup(index: Int) {
        suggestionManager?.previousSuggestionInGroup(index: index)
    }

    func nextSuggestionGroup() {
        suggestionManager?.nextSuggestionGroup()
    }

    func previousSuggestionGroup() {
        suggestionManager?.previousSuggestionGroup()
    }
}

public struct PresentingCodeSuggestion: Equatable {
    public var code: String
    public var language: String
    public var startLineIndex: Int
    public var suggestionCount: Int
    public var currentSuggestionIndex: Int
    public var replacingRange: CursorRange
    public var replacingLines: [String]
    public var descriptions: [CodeSuggestion.Description]

    public init(
        code: String,
        language: String,
        startLineIndex: Int,
        suggestionCount: Int,
        currentSuggestionIndex: Int,
        replacingRange: CursorRange,
        replacingLines: [String],
        descriptions: [CodeSuggestion.Description] = []
    ) {
        self.code = code
        self.language = language
        self.startLineIndex = startLineIndex
        self.suggestionCount = suggestionCount
        self.currentSuggestionIndex = currentSuggestionIndex
        self.replacingRange = replacingRange
        self.replacingLines = replacingLines
        self.descriptions = descriptions
    }
}

struct SuggestionPanelGroupView: View {
    let manager: PresentingCodeSuggestionManager
    let alignment: HorizontalAlignment
    @Namespace var namespace

    var body: some View {
        WithPerceptionTracking {
            let displaySuggestions = manager.displaySuggestions
            VStack(alignment: alignment, spacing: 0) {
                ForEach(displaySuggestions.indices, id: \.self) { index in
                    let isFirst = index == 0
                    if index >= 0, index < displaySuggestions.count {
                        let suggestion = displaySuggestions[index]
                        switch suggestion {
                        case let .group(group):
                            if let suggestion = group.activeSuggestion {
                                CodeBlockSuggestionPanelView(
                                    suggestion: PresentingCodeSuggestion(
                                        code: suggestion.text,
                                        language: manager.filespace.language.rawValue,
                                        startLineIndex: suggestion.position.line,
                                        suggestionCount: group.suggestions.count,
                                        currentSuggestionIndex: group.suggestionIndex,
                                        replacingRange: suggestion.range,
                                        replacingLines: suggestion.replacingLines,
                                        descriptions: suggestion.descriptions
                                    ),
                                    groupIndex: index
                                )
                                .id(suggestion.id)
                                .matchedGeometryEffect(id: suggestion.id, in: namespace)
                                .opacity(isFirst ? 1 : 0.8)
                            }
                        case let .action(action):
                            ActionSuggestionPanel(
                                descriptions: action.descriptions,
                                suggestionCount: 1,
                                suggestionIndex: 0,
                                groupIndex: index
                            )
                            .id(suggestion.id)
                            .matchedGeometryEffect(id: suggestion.id, in: namespace)
                            .opacity(isFirst ? 1 : 0.8)
                        }
                    }
                }
            }
            .animation(.linear(duration: 0.1), value: displaySuggestions)
        }
    }
}

struct ActionSuggestionPanel: View {
    @Dependency(\.commandHandler) var commandHandler
    @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode
    @AppStorage(\.suggestionDisplayCompactMode) var suggestionDisplayCompactMode
    @Environment(\.colorScheme) var colorScheme
    @Namespace var dismissButtonSpace

    let descriptions: [CodeSuggestion.Description]
    let suggestionCount: Int
    let suggestionIndex: Int
    let groupIndex: Int

    init(
        descriptions: [CodeSuggestion.Description],
        suggestionCount: Int,
        suggestionIndex: Int,
        groupIndex: Int
    ) {
        self.descriptions = descriptions.sorted { lhs, _ in lhs.kind != .action }
        self.suggestionCount = suggestionCount
        self.suggestionIndex = suggestionIndex
        self.groupIndex = groupIndex
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    // accept action
                }) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<descriptions.endIndex, id: \.self) { index in
                            let isFirst = index == 0
                            Group {
                                switch descriptions[index].kind {
                                case .warning:
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(Image(systemName: "exclamationmark.circle.fill"))
                                        Text(descriptions[index].content)

                                        if isFirst {
                                            Color.clear.frame(width: 24, height: 1)
                                        }
                                    }
                                    .multilineTextAlignment(.leading)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 4)
                                    .background(.orange.opacity(0.9))
                                case .action:
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text(Image(systemName: "arrowshape.right.circle.fill"))
                                        Text(descriptions[index].content)

                                        if isFirst {
                                            Color.clear.frame(width: 24, height: 1)
                                        }
                                    }
                                    .multilineTextAlignment(.leading)

                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 4)
                                    .background(.cyan.opacity(0.9))
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    Button(action: {
                        Task {
                            await commandHandler.dismissSuggestion()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .padding(.trailing, 4)
                            .contentShape(.circle)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if suggestionCount > 1 {
                    HStack {
                        Button(action: {
                            Task { await commandHandler.presentPreviousSuggestion(atIndex: nil) }
                        }) {
                            Image(systemName: "chevron.left")
                        }.buttonStyle(.plain)

                        Text("\(suggestionIndex + 1) / \(suggestionCount)")
                            .monospacedDigit()

                        Button(action: {
                            Task { await commandHandler.presentNextSuggestion(atIndex: nil) }
                        }) {
                            Image(systemName: "chevron.right")
                        }.buttonStyle(.plain)
                    }
                    .padding(6)
                    .foregroundColor(.secondary)
                }
            }
            .colorScheme(.dark)
            .background(.regularMaterial)
        }
        .xcodeStyleFrame(cornerRadius: {
            switch suggestionPresentationMode {
            case .nearbyTextCursor: 6
            case .floatingWidget: nil
            }
        }())
    }
}

struct CodeBlockSuggestionPanelView: View {
    let suggestion: PresentingCodeSuggestion
    let groupIndex: Int
    @Environment(\.textCursorTracker) var textCursorTracker
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.suggestionCodeFont) var codeFont
    @AppStorage(\.suggestionDisplayCompactMode) var suggestionDisplayCompactMode
    @AppStorage(\.suggestionPresentationMode) var suggestionPresentationMode
    @AppStorage(\.hideCommonPrecedingSpacesInSuggestion) var hideCommonPrecedingSpaces
    @AppStorage(\.syncSuggestionHighlightTheme) var syncHighlightTheme
    @AppStorage(\.codeForegroundColorLight) var codeForegroundColorLight
    @AppStorage(\.codeForegroundColorDark) var codeForegroundColorDark
    @AppStorage(\.codeBackgroundColorLight) var codeBackgroundColorLight
    @AppStorage(\.codeBackgroundColorDark) var codeBackgroundColorDark

    struct ToolBar: View {
        @Dependency(\.commandHandler) var commandHandler
        let suggestion: PresentingCodeSuggestion
        let groupIndex: Int

        var body: some View {
            WithPerceptionTracking {
                HStack {
                    if suggestion.suggestionCount > 1 {
                        Button(action: {
                            Task {
                                await commandHandler.presentPreviousSuggestion(atIndex: groupIndex)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                        }.buttonStyle(.plain)

                        Text(
                            "\(suggestion.currentSuggestionIndex + 1) / \(suggestion.suggestionCount)"
                        )
                        .monospacedDigit()

                        Button(action: {
                            Task { await commandHandler.presentNextSuggestion(atIndex: groupIndex) }
                        }) {
                            Image(systemName: "chevron.right")
                        }.buttonStyle(.plain)
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            await commandHandler.dismissSuggestion()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Text("Dismiss").foregroundStyle(.tertiary).padding(.trailing, 4)
                    }.buttonStyle(.plain)

                    Button(action: {
                        Task {
                            await commandHandler.rejectSuggestionGroup(atIndex: groupIndex)
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Text("Reject")
                    }.buttonStyle(CommandButtonStyle(color: .gray))

                    Button(action: {
                        Task {
                            await commandHandler.acceptActiveSuggestionInGroup(atIndex: groupIndex)
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Text("Accept")
                    }.buttonStyle(CommandButtonStyle(color: .accentColor))
                }
                .padding(6)
                .foregroundColor(.secondary)
                .background(.regularMaterial)
            }
        }
    }

    struct CompactToolBar: View {
        @Dependency(\.commandHandler) var commandHandler
        let suggestion: PresentingCodeSuggestion
        let groupIndex: Int

        var body: some View {
            WithPerceptionTracking {
                HStack {
                    if suggestion.suggestionCount > 1 {
                        Button(action: {
                            Task {
                                await commandHandler.presentPreviousSuggestion(atIndex: groupIndex)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                        }.buttonStyle(.plain)

                        Text(
                            "\(suggestion.currentSuggestionIndex + 1) / \(suggestion.suggestionCount)"
                        )
                        .monospacedDigit()

                        Button(action: {
                            Task { await commandHandler.presentNextSuggestion(atIndex: groupIndex) }
                        }) {
                            Image(systemName: "chevron.right")
                        }.buttonStyle(.plain)
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            await commandHandler.dismissSuggestion()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }) {
                        Image(systemName: "xmark")
                    }.buttonStyle(.plain)
                }
                .padding(4)
                .font(.caption)
                .foregroundColor(.secondary)
                .background(.regularMaterial)
            }
        }
    }

    struct ActionToolBar: View {
        var body: some View {
            EmptyView()
        }
    }

    struct Description: View {
        var descriptions: [CodeSuggestion.Description]

        var body: some View {
            VStack(spacing: 0) {
                ForEach(0..<descriptions.endIndex, id: \.self) { index in
                    Group {
                        switch descriptions[index].kind {
                        case .warning:
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(Image(systemName: "exclamationmark.circle.fill"))
                                Text(descriptions[index].content)
                            }
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .background(.orange.opacity(0.9))

                            Divider().background(Color.red)
                        case .action:
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(Image(systemName: "arrowshape.right.circle.fill"))
                                Text(descriptions[index].content)
                            }
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .background(.cyan.opacity(0.9))

                            Divider().background(Color.blue)
                        }
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                let hasCodeSuggestion = !(
                    suggestion.code.isEmpty && suggestion.replacingRange.isEmpty
                )
                if hasCodeSuggestion {
                    ScrollView {
                        WithPerceptionTracking {
                            let (code, originalCode, dimmedCharacterCount) = extractCode()
                            AsyncCodeBlock(
                                code: code,
                                originalCode: originalCode,
                                language: suggestion.language,
                                startLineIndex: suggestion.startLineIndex,
                                scenario: "suggestion",
                                font: codeFont.value.nsFont,
                                droppingLeadingSpaces: hideCommonPrecedingSpaces,
                                proposedForegroundColor: {
                                    if syncHighlightTheme {
                                        if colorScheme == .light,
                                           let color = codeForegroundColorLight.value?.swiftUIColor
                                        {
                                            return color
                                        } else if let color = codeForegroundColorDark.value?
                                            .swiftUIColor
                                        {
                                            return color
                                        }
                                    }
                                    return nil
                                }(),
                                dimmedCharacterCount: dimmedCharacterCount
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background({ () -> Color in
                                if syncHighlightTheme {
                                    if colorScheme == .light,
                                       let color = codeBackgroundColorLight.value?.swiftUIColor
                                    {
                                        return color
                                    } else if let color = codeBackgroundColorDark.value?
                                        .swiftUIColor
                                    {
                                        return color
                                    }
                                }
                                return Color.contentBackground
                            }())
                        }
                    }
                }

                Description(descriptions: suggestion.descriptions)

                Divider()

                if suggestionDisplayCompactMode {
                    CompactToolBar(suggestion: suggestion, groupIndex: groupIndex)
                } else {
                    ToolBar(suggestion: suggestion, groupIndex: groupIndex)
                }
            }
            .xcodeStyleFrame(cornerRadius: {
                switch suggestionPresentationMode {
                case .nearbyTextCursor: 6
                case .floatingWidget: nil
                }
            }())
        }
    }

    @MainActor
    func extractCode() -> (
        code: String,
        originalCode: String,
        dimmedCharacterCount: AsyncCodeBlock.DimmedCharacterCount
    ) {
        var range = suggestion.replacingRange
        range.end = .init(line: range.end.line - range.start.line, character: range.end.character)
        range.start = .init(line: 0, character: range.start.character)
        let codeInRange = EditorInformation.code(in: suggestion.replacingLines, inside: range)
        let leftover = {
            if range.end.line >= 0, range.end.line < suggestion.replacingLines.endIndex {
                let lastLine = suggestion.replacingLines[range.end.line]
                if range.end.character < lastLine.utf16.count {
                    let startIndex = lastLine.utf16.index(
                        lastLine.utf16.startIndex,
                        offsetBy: range.end.character
                    )
                    var leftover = String(lastLine.utf16.suffix(from: startIndex))
                    if leftover?.last?.isNewline ?? false {
                        leftover?.removeLast(1)
                    }
                    return leftover ?? ""
                }
            }
            return ""
        }()

        let prefix = {
            if range.start.line >= 0, range.start.line < suggestion.replacingLines.endIndex {
                let firstLine = suggestion.replacingLines[range.start.line]
                if range.start.character < firstLine.utf16.count {
                    let endIndex = firstLine.utf16.index(
                        firstLine.utf16.startIndex,
                        offsetBy: range.start.character
                    )
                    let prefix = String(firstLine.utf16.prefix(upTo: endIndex))
                    return prefix ?? ""
                }
            }
            return ""
        }()

        let code = prefix + suggestion.code + leftover

        let typedCount = suggestion.startLineIndex == textCursorTracker.cursorPosition.line
            ? textCursorTracker.cursorPosition.character
            : 0

        return (
            code,
            codeInRange.code,
            .init(prefix: typedCount, suffix: leftover.utf16.count)
        )
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Suggestion Panel Group") {
    SuggestionPanelGroupView(
        manager: .init(
            filespace: {
                let filespace = Filespace.preview(fileURL: URL(fileURLWithPath: "/file.swift"))
                filespace.plugin(for: FileSuggestionManagerPlugin.self)?.suggestionManager
                    .receiveSuggestions([
                        .init(
                            id: "1",
                            text: "Text",
                            position: .init(line: 0, character: 0),
                            range: .init(
                                start: .init(line: 0, character: 0),
                                end: .init(line: 0, character: 0)
                            ),
                            replacingLines: [],
                            descriptions: [],
                            metadata: ["source": "source 1"]
                        ),
                        .init(
                            id: "2",
                            text: "Text",
                            position: .init(line: 0, character: 0),
                            range: .init(
                                start: .init(line: 0, character: 0),
                                end: .init(line: 0, character: 0)
                            ),
                            replacingLines: [],
                            descriptions: [],
                            metadata: ["source": "source 2"]
                        ),
                        .init(
                            id: "3",
                            text: "Text",
                            position: .init(line: 0, character: 0),
                            range: .init(
                                start: .init(line: 0, character: 0),
                                end: .init(line: 0, character: 0)
                            ),
                            replacingLines: [],
                            descriptions: [],
                            metadata: ["source": "source 2"]
                        ),
                        .init(
                            id: "4",
                            text: "",
                            position: .init(line: 0, character: 0),
                            range: .init(
                                start: .init(line: 0, character: 0),
                                end: .init(line: 0, character: 0)
                            ),
                            replacingLines: [],
                            descriptions: [
                                .init(kind: .action, content: "This is an action message."),
                            ]
                        ),
                        .init(
                            id: "5",
                            text: "",
                            position: .init(line: 0, character: 0),
                            range: .init(
                                start: .init(line: 0, character: 0),
                                end: .init(line: 0, character: 0)
                            ),
                            replacingLines: [],
                            descriptions: [
                                .init(kind: .action, content: "This is an action message."),
                            ]
                        ),
                    ])
                return filespace
            }()
        ),
        alignment: .leading
    )
    .frame(width: 450, height: 500)
    .padding()
}
#endif

#Preview("Code Block Suggestion Panel") {
    CodeBlockSuggestionPanelView(suggestion: PresentingCodeSuggestion(
        code: """
        LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
        ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
            Text(viewModel.suggestion[index])
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        """,
        language: "swift",
        startLineIndex: 8,
        suggestionCount: 2,
        currentSuggestionIndex: 0,
        replacingRange: .outOfScope,
        replacingLines: []
    ), groupIndex: 0, suggestionDisplayCompactMode: .init(
        wrappedValue: false,
        "suggestionDisplayCompactMode",
        store: {
            let userDefault =
                UserDefaults(suiteName: "CodeBlockSuggestionPanel_CompactToolBar_Preview")
            userDefault?.set(false, for: \.suggestionDisplayCompactMode)
            return userDefault!
        }()
    ))
    .frame(width: 450, height: 400)
    .padding()
}

#Preview("Code Block Suggestion Panel With Descriptions") {
    CodeBlockSuggestionPanelView(suggestion: PresentingCodeSuggestion(
        code: """
        LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
        ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
            Text(viewModel.suggestion[index])
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        """,
        language: "swift",
        startLineIndex: 8,
        suggestionCount: 2,
        currentSuggestionIndex: 0,
        replacingRange: .outOfScope,
        replacingLines: [],
        descriptions: [
            .init(kind: .warning, content: "This is a warning message.\nwarning"),
            .init(kind: .action, content: "This is an action message."),
        ]
    ), groupIndex: 0, suggestionDisplayCompactMode: .init(
        wrappedValue: false,
        "suggestionDisplayCompactMode",
        store: {
            let userDefault =
                UserDefaults(suiteName: "CodeBlockSuggestionPanel_CompactToolBar_Preview")
            userDefault?.set(false, for: \.suggestionDisplayCompactMode)
            return userDefault!
        }()
    ))
    .frame(width: 450, height: 400)
    .padding()
}

#Preview("Code Block Suggestion Panel Compact Mode") {
    CodeBlockSuggestionPanelView(suggestion: PresentingCodeSuggestion(
        code: """
        LazyVGrid(columns: [GridItem(.fixed(30)), GridItem(.flexible())]) {
        ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in // lkjaskldjalksjdlkasjdlkajslkdjas
            Text(viewModel.suggestion[index])
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        """,
        language: "swift",
        startLineIndex: 8,
        suggestionCount: 2,
        currentSuggestionIndex: 0,
        replacingRange: .outOfScope,
        replacingLines: [],
        descriptions: [
            .init(kind: .warning, content: "This is a warning message."),
            .init(kind: .action, content: "This is an action message."),
        ]
    ), groupIndex: 0, suggestionDisplayCompactMode: .init(
        wrappedValue: true,
        "suggestionDisplayCompactMode",
        store: {
            let userDefault =
                UserDefaults(suiteName: "CodeBlockSuggestionPanel_CompactToolBar_Preview")
            userDefault?.set(true, for: \.suggestionDisplayCompactMode)
            return userDefault!
        }()
    ))
    .preferredColorScheme(.light)
    .frame(width: 450, height: 400)
    .padding()
}

#Preview("Code Block Suggestion Panel Highlight ObjC") {
    CodeBlockSuggestionPanelView(suggestion: PresentingCodeSuggestion(
        code: """
        - (void)addSubview:(UIView *)view {
            [self addSubview:view];
        }
        """,
        language: "objective-c",
        startLineIndex: 8,
        suggestionCount: 2,
        currentSuggestionIndex: 0,
        replacingRange: .outOfScope,
        replacingLines: []
    ), groupIndex: 0)
        .preferredColorScheme(.light)
        .frame(width: 450, height: 400)
        .padding()
}


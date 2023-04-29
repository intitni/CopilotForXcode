import LaunchAgentManager
import Preferences
import SwiftUI

struct SettingsView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.quitXPCServiceOnXcodeAndAppQuit)
        var quitXPCServiceOnXcodeAndAppQuit: Bool
        @AppStorage(\.realtimeSuggestionToggle)
        var realtimeSuggestionToggle: Bool
        @AppStorage(\.realtimeSuggestionDebounce)
        var realtimeSuggestionDebounce: Double
        @AppStorage(\.suggestionPresentationMode)
        var suggestionPresentationMode: Preferences.PresentationMode
        @AppStorage(\.suggestionWidgetPositionMode)
        var suggestionWidgetPositionMode: SuggestionWidgetPositionMode
        @AppStorage(\.widgetColorScheme)
        var widgetColorScheme: WidgetColorScheme
        @AppStorage(\.acceptSuggestionWithAccessibilityAPI)
        var acceptSuggestionWithAccessibilityAPI: Bool
        @AppStorage(\.disableSuggestionFeatureGlobally)
        var disableSuggestionFeatureGlobally: Bool
        @AppStorage(\.suggestionFeatureEnabledProjectList)
        var suggestionFeatureEnabledProjectList: [String]
        @AppStorage(\.promptToCodeFeatureProvider)
        var promptToCodeFeatureProvider: PromptToCodeFeatureProvider
        @AppStorage(\.preferWidgetToStayInsideEditorWhenWidthGreaterThan)
        var preferWidgetToStayInsideEditorWhenWidthGreaterThan: Double
        @AppStorage(\.hideCommonPrecedingSpacesInSuggestion)
        var hideCommonPrecedingSpacesInSuggestion: Bool
        @AppStorage(\.suggestionCodeFontSize) var suggestionCodeFontSize
        @AppStorage(\.chatFontSize) var chatFontSize
        @AppStorage(\.chatCodeFontSize) var chatCodeFontSize
        init() {}
    }

    @StateObject var settings = Settings()
    @State var editingRealtimeSuggestionDebounce: Double = UserDefaults.shared
        .value(for: \.realtimeSuggestionDebounce)
    @Environment(\.updateChecker) var updateChecker
    @State var isSuggestionFeatureEnabledListPickerOpen = false
    @State var isCustomCommandEditorOpen = false

    var body: some View {
        Section {
            Button("Edit Custom Commands") {
                isCustomCommandEditorOpen = true
            }
            .buttonStyle(.copilot)
            .sheet(isPresented: $isCustomCommandEditorOpen) {
                CustomCommandView(
                    isOpen: $isCustomCommandEditorOpen
                )
            }

            Form {
                Toggle(isOn: $settings.quitXPCServiceOnXcodeAndAppQuit) {
                    Text("Quit service when Xcode and host app are terminated")
                }
                .toggleStyle(.switch)

                Toggle(isOn: .init(
                    get: { updateChecker.automaticallyChecksForUpdates },
                    set: { updateChecker.automaticallyChecksForUpdates = $0 }
                )) {
                    Text("Automatically Check for Update")
                }
                .toggleStyle(.switch)

                Picker(selection: $settings.suggestionPresentationMode) {
                    ForEach(PresentationMode.allCases, id: \.rawValue) {
                        switch $0 {
                        case .comment:
                            Text("Comment").tag($0)
                        case .floatingWidget:
                            Text("Floating Widget").tag($0)
                        }
                    }
                } label: {
                    Text("Present suggestions in")
                }

                if settings.suggestionPresentationMode == PresentationMode.floatingWidget {
                    Picker(selection: $settings.suggestionWidgetPositionMode) {
                        ForEach(SuggestionWidgetPositionMode.allCases, id: \.rawValue) {
                            switch $0 {
                            case .fixedToBottom:
                                Text("Fixed to Bottom").tag($0)
                            case .alignToTextCursor:
                                Text("Follow Text Cursor").tag($0)
                            }
                        }
                    } label: {
                        Text("Widget position")
                    }

                    Picker(selection: $settings.widgetColorScheme) {
                        ForEach(WidgetColorScheme.allCases, id: \.rawValue) {
                            switch $0 {
                            case .system:
                                Text("System").tag($0)
                            case .light:
                                Text("Light").tag($0)
                            case .dark:
                                Text("Dark").tag($0)
                            }
                        }
                    } label: {
                        Text("Widget color scheme")
                    }
                }

                Group {
                    Toggle(isOn: $settings.realtimeSuggestionToggle) {
                        Text("Real-time suggestion")
                    }
                    .toggleStyle(.switch)

                    HStack {
                        Toggle(isOn: $settings.disableSuggestionFeatureGlobally) {
                            Text("Disable suggestion feature globally")
                        }
                        .toggleStyle(.switch)

                        Button("Enabled Projects") {
                            isSuggestionFeatureEnabledListPickerOpen = true
                        }
                    }.sheet(isPresented: $isSuggestionFeatureEnabledListPickerOpen) {
                        SuggestionFeatureEnabledProjectListView(
                            isOpen: $isSuggestionFeatureEnabledListPickerOpen
                        )
                    }

                    HStack {
                        Slider(value: $editingRealtimeSuggestionDebounce, in: 0...2, step: 0.1) {
                            Text("Real-time suggestion fetch debounce")
                        } onEditingChanged: { _ in
                            settings.realtimeSuggestionDebounce = editingRealtimeSuggestionDebounce
                        }

                        Text(
                            "\(editingRealtimeSuggestionDebounce.formatted(.number.precision(.fractionLength(2))))s"
                        )
                        .font(.body)
                        .monospacedDigit()
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(0.2))
                        )
                    }

                    Toggle(isOn: $settings.hideCommonPrecedingSpacesInSuggestion) {
                        Text("Hide Common Preceding Spaces in Suggestion")
                    }
                    .toggleStyle(.switch)

                    Toggle(isOn: $settings.acceptSuggestionWithAccessibilityAPI) {
                        Text("Use accessibility API to accept suggestion in widget")
                    }
                    .toggleStyle(.switch)
                }

                Picker(selection: $settings.promptToCodeFeatureProvider) {
                    ForEach(PromptToCodeFeatureProvider.allCases, id: \.rawValue) {
                        switch $0 {
                        case .openAI:
                            Text("OpenAI").tag($0)
                        case .githubCopilot:
                            Text(
                                "GitHub Copilot (Implement for experiment, barely works, don't use.)"
                            )
                            .tag($0)
                        }
                    }
                } label: {
                    Text("Prompt to code with")
                }

                HStack {
                    TextField(text: .init(get: {
                        "\(Int(settings.preferWidgetToStayInsideEditorWhenWidthGreaterThan))"
                    }, set: {
                        settings
                            .preferWidgetToStayInsideEditorWhenWidthGreaterThan =
                            Double(Int($0) ?? 0)
                    })) {
                        Text("Prefer widget to be inside editor when width greater than")
                    }
                    .textFieldStyle(.roundedBorder)

                    Text("pt")
                }

                Group { // UI
                    HStack {
                        TextField(text: .init(get: {
                            "\(Int(settings.chatFontSize))"
                        }, set: {
                            settings.chatFontSize = Double(Int($0) ?? 0)
                        })) {
                            Text("Font size of chat message")
                        }
                        .textFieldStyle(.roundedBorder)

                        Text("pt")
                    }
                    
                    HStack {
                        TextField(text: .init(get: {
                            "\(Int(settings.chatCodeFontSize))"
                        }, set: {
                            settings.chatCodeFontSize = Double(Int($0) ?? 0)
                        })) {
                            Text("Font size of code block in chat")
                        }
                        .textFieldStyle(.roundedBorder)

                        Text("pt")
                    }
                    
                    HStack {
                        TextField(text: .init(get: {
                            "\(Int(settings.suggestionCodeFontSize))"
                        }, set: {
                            settings.suggestionCodeFontSize = Double(Int($0) ?? 0)
                        })) {
                            Text("Font size of suggestion code")
                        }
                        .textFieldStyle(.roundedBorder)

                        Text("pt")
                    }
                }
            }
        }.buttonStyle(.copilot)
    }
}

struct SuggestionFeatureEnabledProjectListView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.suggestionFeatureEnabledProjectList)
        var suggestionFeatureEnabledProjectList: [String]

        init(suggestionFeatureEnabledProjectList: AppStorage<[String]>? = nil) {
            if let list = suggestionFeatureEnabledProjectList {
                _suggestionFeatureEnabledProjectList = list
            }
        }
    }

    var isOpen: Binding<Bool>
    @State var isAddingNewProject = false
    @StateObject var settings = Settings()

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    self.isOpen.wrappedValue = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .buttonStyle(.plain)
                Text("Enabled Projects")
                Spacer()
                Button(action: {
                    isAddingNewProject = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .buttonStyle(.plain)
            }
            .background(.black.opacity(0.2))

            List {
                ForEach(
                    settings.suggestionFeatureEnabledProjectList,
                    id: \.self
                ) { project in
                    HStack {
                        Text(project)
                            .contextMenu {
                                Button("Remove") {
                                    settings.suggestionFeatureEnabledProjectList.removeAll(
                                        where: { $0 == project }
                                    )
                                }
                            }
                        Spacer()

                        Button(action: {
                            settings.suggestionFeatureEnabledProjectList.removeAll(
                                where: { $0 == project }
                            )
                        }) {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .overlay {
                if settings.suggestionFeatureEnabledProjectList.isEmpty {
                    Text("""
                    Empty
                    Add project with "+" button
                    Or right clicking the circular widget
                    """)
                    .multilineTextAlignment(.center)
                }
            }
        }
        .frame(width: 300, height: 400)
        .sheet(isPresented: $isAddingNewProject) {
            SuggestionFeatureAddEnabledProjectView(isOpen: $isAddingNewProject, settings: settings)
        }
    }
}

struct SuggestionFeatureAddEnabledProjectView: View {
    var isOpen: Binding<Bool>
    var settings: SuggestionFeatureEnabledProjectListView.Settings
    @State var rootPath = ""

    var body: some View {
        VStack {
            Text(
                "Enter the root path of the project. Do not use `~` to replace /Users/yourUserName."
            )
            TextField("Root path", text: $rootPath)
            HStack {
                Spacer()
                Button("Cancel") {
                    isOpen.wrappedValue = false
                }
                Button("Add") {
                    settings.suggestionFeatureEnabledProjectList.append(rootPath)
                    isOpen.wrappedValue = false
                }
            }.buttonStyle(.copilot)
        }
        .padding()
        .frame(minWidth: 500)
    }
}

// MARK: - Previews

struct SettingsView_Preview: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .background(.purple)
    }
}

struct SuggestionFeatureEnabledProjectListView_Preview: PreviewProvider {
    static var previews: some View {
        SuggestionFeatureEnabledProjectListView(
            isOpen: .constant(true),
            settings: .init(suggestionFeatureEnabledProjectList: .init(wrappedValue: [
                "hello/2",
                "hello/3",
                "hello/4",
            ], "SuggestionFeatureEnabledProjectListView_Preview"))
        )
        .background(.purple)
    }
}

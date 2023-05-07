import Preferences
import SwiftUI

struct SuggestionSettingsView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.realtimeSuggestionToggle)
        var realtimeSuggestionToggle
        @AppStorage(\.realtimeSuggestionDebounce)
        var realtimeSuggestionDebounce
        @AppStorage(\.suggestionPresentationMode)
        var suggestionPresentationMode
        @AppStorage(\.acceptSuggestionWithAccessibilityAPI)
        var acceptSuggestionWithAccessibilityAPI
        @AppStorage(\.disableSuggestionFeatureGlobally)
        var disableSuggestionFeatureGlobally
        @AppStorage(\.suggestionFeatureEnabledProjectList)
        var suggestionFeatureEnabledProjectList
        @AppStorage(\.hideCommonPrecedingSpacesInSuggestion)
        var hideCommonPrecedingSpacesInSuggestion
        @AppStorage(\.suggestionCodeFontSize)
        var suggestionCodeFontSize
        @AppStorage(\.suggestionFeatureProvider)
        var suggestionFeatureProvider
        init() {}
    }

    @StateObject var settings = Settings()
    @State var isSuggestionFeatureEnabledListPickerOpen = false

    var body: some View {
        Form {
            Group {
                Picker(selection: $settings.suggestionPresentationMode) {
                    ForEach(PresentationMode.allCases, id: \.rawValue) {
                        switch $0 {
                        case .comment:
                            Text("Comment (Deprecating Soon)").tag($0)
                        case .floatingWidget:
                            Text("Floating Widget").tag($0)
                        }
                    }
                } label: {
                    Text("Presentation")
                }
                
                Picker(selection: $settings.suggestionFeatureProvider) {
                    ForEach(SuggestionFeatureProvider.allCases, id: \.rawValue) {
                        switch $0 {
                        case .gitHubCopilot:
                            Text("GitHub Copilot").tag($0)
                        case .codeium:
                            Text("Codeium").tag($0)
                        }
                    }
                } label: {
                    Text("Feature Provider")
                }
                
                Toggle(isOn: $settings.realtimeSuggestionToggle) {
                    Text("Real-time suggestion")
                }
                
                HStack {
                    Toggle(isOn: $settings.disableSuggestionFeatureGlobally) {
                        Text("Disable Suggestion Feature Globally")
                    }
                    
                    Button("Exception List") {
                        isSuggestionFeatureEnabledListPickerOpen = true
                    }
                }.sheet(isPresented: $isSuggestionFeatureEnabledListPickerOpen) {
                    SuggestionFeatureEnabledProjectListView(
                        isOpen: $isSuggestionFeatureEnabledListPickerOpen
                    )
                }
                
                Toggle(isOn: $settings.hideCommonPrecedingSpacesInSuggestion) {
                    Text("Hide Common Preceding Spaces")
                }
                HStack {
                    Slider(value: $settings.realtimeSuggestionDebounce, in: 0...2, step: 0.1) {
                        Text("Real-time Suggestion Debounce")
                    }
                    
                    Text(
                        "\(settings.realtimeSuggestionDebounce.formatted(.number.precision(.fractionLength(2))))s"
                    )
                    .font(.body)
                    .monospacedDigit()
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.primary.opacity(0.1))
                    )
                }
                
                Divider()
            }

            Group {
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
                Divider()
            }

            Group {
                Toggle(isOn: $settings.acceptSuggestionWithAccessibilityAPI) {
                    Text("Use accessibility API to accept suggestion in widget")
                }

                Text("You can turn it on if the accept button is not working for you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
        VStack(spacing: 0) {
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
            .background(Color(nsColor: .separatorColor))

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
            .removeBackground()
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
            }
        }
        .padding()
        .frame(minWidth: 500)
    }
}

struct SuggestionSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SuggestionSettingsView()
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
    }
}


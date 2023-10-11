import SharedUIComponents
import SwiftUI

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
                .modify { view in
                    if #available(macOS 13.0, *) {
                        view.listRowSeparator(.hidden).listSectionSeparator(.hidden)
                    } else {
                        view
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
        .focusable(false)
        .frame(width: 300, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
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
        .background(Color(nsColor: .windowBackgroundColor))
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


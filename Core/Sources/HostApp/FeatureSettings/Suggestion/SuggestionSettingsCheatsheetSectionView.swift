import Client
import Preferences
import SharedUIComponents
import SwiftUI
import XPCShared

#if canImport(ProHostApp)
import ProHostApp
#endif

struct SuggestionSettingsCheatsheetSectionView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.isSuggestionSenseEnabled)
        var isSuggestionSenseEnabled
        @AppStorage(\.isSuggestionTypeInTheMiddleEnabled)
        var isSuggestionTypeInTheMiddleEnabled
    }

    @StateObject var settings = Settings()

    var body: some View {
        #if canImport(ProHostApp)
        SubSection(
            title: Text("Suggestion Sense (Experimental)"),
            description: Text("""
            This cheatsheet will try to improve the suggestion by inserting relevant symbol \
            interfaces in the editing scope to the prompt. 
            
            Some suggestion services may have their own RAG system with a higher priority.
            """)
        ) {
            Form {
                WithFeatureEnabled(\.suggestionSense) {
                    Toggle(isOn: $settings.isSuggestionSenseEnabled) {
                        Text("Enable suggestion sense")
                    }
                }
            }
        }

        SubSection(
            title: Text("Type-in-the-Middle Hack"),
            description: Text("""
            Suggestion service don't always handle the case where the text cursor is in the middle \
            of a line. This cheatsheet will try to trick the suggestion service to also generate \
            suggestions in these cases.
            
            It can be useful in the following cases:
            - Fixing a typo in the middle of a line.
            - Getting suggestions from a line with Xcode placeholders.
            - and more...
            """)
        ) {
            Form {
                Toggle(isOn: $settings.isSuggestionTypeInTheMiddleEnabled) {
                    Text("Enable type-in-the-middle hack")
                }
            }
        }

        #else
        Text("Not Available")
        #endif
    }
}

#Preview {
    SuggestionSettingsCheatsheetSectionView()
        .padding()
}


import Foundation
import Preferences
import SwiftUI

public struct CodeHighlightThemePicker: View {
    public enum Scenario {
        case suggestion
        case promptToCode
        case chat
    }

    let scenario: Scenario

    public init(scenario: Scenario) {
        self.scenario = scenario
    }

    public var body: some View {
        switch scenario {
        case .suggestion:
            SuggestionThemePicker()
        case .promptToCode:
            PromptToCodeThemePicker()
        case .chat:
            ChatThemePicker()
        }
    }

    struct SuggestionThemePicker: View {
        @AppStorage(\.syncSuggestionHighlightTheme) var sync: Bool
        var body: some View {
            SyncToggle(sync: $sync)
        }
    }

    struct PromptToCodeThemePicker: View {
        @AppStorage(\.syncPromptToCodeHighlightTheme) var sync: Bool
        var body: some View {
            SyncToggle(sync: $sync)
        }
    }

    struct ChatThemePicker: View {
        @AppStorage(\.syncChatCodeHighlightTheme) var sync: Bool
        var body: some View {
            SyncToggle(sync: $sync)
        }
    }

    struct SyncToggle: View {
        @Binding var sync: Bool

        var body: some View {
            VStack(alignment: .leading) {
                Toggle(isOn: $sync) {
                    Text("Sync color scheme with Xcode")
                }

                Text("To refresh the theme, you must activate the extension service app once.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    @State var sync = false
    return CodeHighlightThemePicker.SyncToggle(sync: $sync)
}


import ComposableArchitecture
import Foundation
import Preferences
import SwiftUI

struct CodeiumChatTabItem: View {
    @Perception.Bindable var store: StoreOf<CodeiumChatBrowser>

    var body: some View {
        WithPerceptionTracking {
            Text(store.title)
                .contextMenu {
                    CodeiumChatMenuItem(store: store)
                }
        }
    }
}

struct CodeiumChatMenuItem: View {
    @Perception.Bindable var store: StoreOf<CodeiumChatBrowser>

    var body: some View {
        WithPerceptionTracking {
            Button("Load Active Workspace") {
                store.send(.loadCurrentWorkspace)
            }

            Button("Reload") {
                store.send(.reload)
            }
        }
    }
}


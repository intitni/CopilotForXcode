import ComposableArchitecture
import SwiftUI

struct MaxTokensTextField: View {
    @Binding var maxTokens: Int
    var suggestedMaxTokens: Int?

    var body: some View {
        HStack {
            let textFieldBinding = Binding(
                get: { String(maxTokens) },
                set: {
                    if let selectionMaxToken = Int($0) {
                        maxTokens = selectionMaxToken
                    } else {
                        maxTokens = 0
                    }
                }
            )

            TextField(text: textFieldBinding) {
                Text("Context Window")
                    .multilineTextAlignment(.trailing)
            }
            .overlay(alignment: .trailing) {
                Stepper(
                    value: $maxTokens,
                    in: 0...Int.max,
                    step: 100
                ) {
                    EmptyView()
                }
            }
            .foregroundColor({
                guard let max = suggestedMaxTokens else {
                    return .primary
                }
                if maxTokens > max {
                    return .red
                }
                return .primary
            }() as Color)

            if let max = suggestedMaxTokens {
                Text("Max: \(max)")
            }
        }
    }
}

struct BaseURLTextField<TrailingContent: View>: View {
    var title: LocalizedStringKey = "Base URL"
    var prompt: Text?
    let store: StoreOf<BaseURLSelection>
    @ViewBuilder var trailingContent: () -> TrailingContent

    var body: some View {
        BaseURLPicker(
            title: title,
            prompt: prompt,
            store: store,
            trailingContent: trailingContent
        )
    }
}

extension BaseURLTextField where TrailingContent == EmptyView {
    init(
        title: LocalizedStringKey = "Base URL",
        prompt: Text?,
        store: StoreOf<BaseURLSelection>
    ) {
        self.init(title: title, prompt: prompt, store: store, trailingContent: { EmptyView() })
    }
}

struct ApiKeyNamePicker: View {
    let store: StoreOf<APIKeySelection>
    var title: LocalizedStringKey = "API Key"

    var body: some View {
        APIKeyPicker(store: store, title: title)
    }
}

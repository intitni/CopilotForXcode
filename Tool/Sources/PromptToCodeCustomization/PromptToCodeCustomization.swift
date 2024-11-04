import ComposableArchitecture
import Dependencies
import Foundation
import ModificationBasic
import SuggestionBasic
import SwiftUI

public enum PromptToCodeCustomization {
    public static var CustomizedUI: any PromptToCodeCustomizedUI = NoPromptToCodeCustomizedUI()
}

public struct PromptToCodeCustomizationContextWrapper<Content: View>: View {
    @State var context: AnyObject
    let content: (AnyObject) -> Content

    init<O: AnyObject>(context: O, @ViewBuilder content: @escaping (O) -> Content) {
        self.context = context
        self.content = { context in
            content(context as! O)
        }
    }

    public var body: some View {
        content(context)
    }
}

public protocol PromptToCodeCustomizedUI {
    typealias PromptToCodeCustomizedViews = (
        extraMenuItems: AnyView?,
        extraButtons: AnyView?,
        extraAcceptButtonVariants: AnyView?,
        inputField: AnyView?
    )

    func callAsFunction<V: View>(
        state: Shared<ModificationState>,
        isInputFieldFocused: Binding<Bool>,
        @ViewBuilder view: @escaping (PromptToCodeCustomizedViews) -> V
    ) -> PromptToCodeCustomizationContextWrapper<V>
}

struct NoPromptToCodeCustomizedUI: PromptToCodeCustomizedUI {
    private class Context {}

    func callAsFunction<V: View>(
        state: Shared<ModificationState>,
        isInputFieldFocused: Binding<Bool>,
        @ViewBuilder view: @escaping (PromptToCodeCustomizedViews) -> V
    ) -> PromptToCodeCustomizationContextWrapper<V> {
        PromptToCodeCustomizationContextWrapper(context: Context()) { _ in
            view((
                extraMenuItems: nil,
                extraButtons: nil,
                extraAcceptButtonVariants: nil,
                inputField: nil
            ))
        }
    }
}


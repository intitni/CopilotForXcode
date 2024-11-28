import ChatBasic
import ComposableArchitecture
import Dependencies
import Foundation
import ModificationBasic
import SuggestionBasic
import SwiftUI

public enum PromptToCodeCustomization {
    public static var CustomizedUI: any PromptToCodeCustomizedUI = NoPromptToCodeCustomizedUI()
    public static var contextInputControllerFactory: (
        Shared<ModificationState>
    ) -> PromptToCodeContextInputController = { _ in
        DefaultPromptToCodeContextInputController()
    }
}

public struct PromptToCodeCustomizationContextWrapper<Content: View>: View {
    @State var context: AnyObject
    let content: (AnyObject) -> Content

    public init<O: AnyObject>(context: O, @ViewBuilder content: @escaping (O) -> Content) {
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
        contextInputField: AnyView?
    )

    func callAsFunction<V: View>(
        state: Shared<ModificationState>,
        delegate: PromptToCodeContextInputControllerDelegate,
        contextInputController: PromptToCodeContextInputController,
        isInputFieldFocused: FocusState<Bool>,
        @ViewBuilder view: @escaping (PromptToCodeCustomizedViews) -> V
    ) -> PromptToCodeCustomizationContextWrapper<V>
}

public protocol PromptToCodeContextInputControllerDelegate {
    func modifyCodeButtonClicked()
}

public protocol PromptToCodeContextInputController: Perception.Perceptible {
    var instruction: NSAttributedString { get set }

    func resolveContext(onStatusChange: @escaping ([String]) async -> Void) async -> (
        instruction: String,
        references: [ChatMessage.Reference],
        topics: [ChatMessage.Reference],
        agent: (() -> any ModificationAgent)?
    )
}

struct NoPromptToCodeCustomizedUI: PromptToCodeCustomizedUI {
    private class Context {}

    func callAsFunction<V: View>(
        state: Shared<ModificationState>,
        delegate: PromptToCodeContextInputControllerDelegate,
        contextInputController: PromptToCodeContextInputController,
        isInputFieldFocused: FocusState<Bool>,
        @ViewBuilder view: @escaping (PromptToCodeCustomizedViews) -> V
    ) -> PromptToCodeCustomizationContextWrapper<V> {
        PromptToCodeCustomizationContextWrapper(context: Context()) { _ in
            view((
                extraMenuItems: nil,
                extraButtons: nil,
                extraAcceptButtonVariants: nil,
                contextInputField: nil
            ))
        }
    }
}

@Perceptible
public final class DefaultPromptToCodeContextInputController: PromptToCodeContextInputController {
    public var instruction: NSAttributedString = .init()
    public var instructionString: String {
        get { instruction.string }
        set { instruction = .init(string: newValue) }
    }

    public func appendNewLineToPromptButtonTapped() {
        let mutable = NSMutableAttributedString(
            attributedString: instruction
        )
        mutable.append(NSAttributedString(string: "\n"))
        instruction = mutable
    }

    public func resolveContext(onStatusChange: @escaping ([String]) async -> Void) -> (
        instruction: String,
        references: [ChatMessage.Reference],
        topics: [ChatMessage.Reference],
        agent: (() -> any ModificationAgent)?
    ) {
        return (
            instruction: instructionString,
            references: [],
            topics: [],
            agent: nil
        )
    }
}


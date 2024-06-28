import ChatBasic
import CodableWrappers
import Foundation

struct Cancellable {
    let cancel: () -> Void
    func callAsFunction() {
        cancel()
    }
}

public typealias ChatMessage = ChatBasic.ChatMessage


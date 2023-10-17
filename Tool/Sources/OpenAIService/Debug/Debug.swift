import AppKit
import Foundation

enum Debugger {
    #if DEBUG
    @TaskLocal
    static var id: UUID?
    #endif

    static func didSendRequestBody(body: CompletionRequestBody) {
        #if DEBUG

        do {
            let json = try JSONEncoder().encode(body)
            let center = NSWorkspace.shared.notificationCenter
            center.post(
                name: .init("ServiceDebugger.ChatRequestDebug.requestSent"),
                object: nil,
                userInfo: [
                    "id": id ?? UUID(),
                    "data": json,
                ]
            )
        } catch {
            print("Failed to encode request body: \(error)")
        }

        #endif
    }

    static func didReceiveFunction(name: String, arguments: String) {
        #if DEBUG

        let center = NSWorkspace.shared.notificationCenter
        center.post(
            name: .init("ServiceDebugger.ChatRequestDebug.receivedFunctionCall"),
            object: nil,
            userInfo: [
                "id": id ?? UUID(),
                "name": name,
                "arguments": arguments,
            ]
        )

        #endif
    }

    static func didReceiveFunctionResult(result: String) {
        #if DEBUG

        let center = NSWorkspace.shared.notificationCenter
        center.post(
            name: .init("ServiceDebugger.ChatRequestDebug.receivedFunctionResult"),
            object: nil,
            userInfo: [
                "id": id ?? UUID(),
                "result": result,
            ]
        )

        #endif
    }

    static func didReceiveResponse(content: String) {
        #if DEBUG

        let center = NSWorkspace.shared.notificationCenter
        center.post(
            name: .init("ServiceDebugger.ChatRequestDebug.responseReceived"),
            object: nil,
            userInfo: [
                "id": id ?? UUID(),
                "response": content,
            ]
        )

        #endif
    }

    static func didFinish() {
        let center = NSWorkspace.shared.notificationCenter
        center.post(
            name: .init("ServiceDebugger.ChatRequestDebug.finished"),
            object: nil,
            userInfo: [
                "id": id ?? UUID(),
            ]
        )
    }
}


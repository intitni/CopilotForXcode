import Foundation
import os.log

enum LogLevel: String {
    case debug
    case info
    case error
}

public final class Logger {
    private let subsystem: String
    private let category: String
    private let osLog: OSLog

    public static let service = Logger(category: "Service")
    public static let ui = Logger(category: "UI")
    public static let client = Logger(category: "Client")
    public static let updateChecker = Logger(category: "UpdateChecker")
    public static let gitHubCopilot = Logger(category: "GitHubCopilot")
    public static let codeium = Logger(category: "Codeium")
    public static let langchain = Logger(category: "LangChain")
    #if DEBUG
    public static let temp = Logger(category: "Temp")
    #endif

    public init(subsystem: String = "com.intii.CopilotForXcode", category: String) {
        self.subsystem = subsystem
        self.category = category
        osLog = OSLog(subsystem: subsystem, category: category)
    }

    func log(level: LogLevel, message: String) {
        let osLogType: OSLogType
        switch level {
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .error:
            osLogType = .error
        }

        os_log("%{public}@", log: osLog, type: osLogType, message as CVarArg)
    }

    public func debug(_ message: String) {
        log(level: .debug, message: message)
    }

    public func info(_ message: String) {
        log(level: .info, message: message)
    }

    public func error(_ message: String) {
        log(level: .error, message: message)
    }

    public func error(_ error: Error) {
        log(level: .error, message: error.localizedDescription)
    }
    
    public func signpost(_ type: OSSignpostType, name: StaticString) {
        os_signpost(type, log: osLog, name: name)
    }
}

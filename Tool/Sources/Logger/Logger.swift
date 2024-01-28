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
    public static let retrieval = Logger(category: "Retrieval")
    public static let license = Logger(category: "License")
    public static let `extension` = Logger(category: "Extension")
    #if DEBUG
    /// Use a temp logger to log something temporary. I won't be available in release builds.
    public static let temp = Logger(category: "Temp")
    #endif

    public init(subsystem: String = "com.intii.CopilotForXcode", category: String) {
        self.subsystem = subsystem
        self.category = category
        osLog = OSLog(subsystem: subsystem, category: category)
    }

    func log(
        level: LogLevel,
        message: String,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
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

    public func debug(
        _ message: String,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        log(level: .debug, message: """
        \(message)
        file: \(file)
        line: \(line)
        function: \(function)
        """, file: file, line: line, function: function)
    }

    public func info(
        _ message: String,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        log(level: .info, message: message, file: file, line: line, function: function)
    }

    public func error(
        _ message: String,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        log(level: .error, message: message, file: file, line: line, function: function)
    }

    public func error(
        _ error: Error,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        log(
            level: .error,
            message: error.localizedDescription,
            file: file,
            line: line,
            function: function
        )
    }
    
    public func signpost(
        _ type: OSSignpostType,
        name: StaticString,
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        os_signpost(type, log: osLog, name: name)
    }
}

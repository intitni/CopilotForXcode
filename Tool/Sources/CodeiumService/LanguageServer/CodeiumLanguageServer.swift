import Foundation
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import Logger
import Preferences
import XcodeInspector

protocol CodeiumLSP {
    func sendRequest<E: CodeiumRequestType>(_ endpoint: E) async throws -> E.Response
    func updateIndexing() async
    func terminate()
}

final class CodeiumLanguageServer {
    let languageServerExecutableURL: URL
    let managerDirectoryURL: URL
    let supportURL: URL
    let process: Process
    let transport: IOTransport
    var terminationHandler: (() -> Void)?
    var launchHandler: (() -> Void)?
    var port: String?
    var heartbeatTask: Task<Void, Error>?
    var projectPaths: [String]

    init(
        languageServerExecutableURL: URL,
        managerDirectoryURL: URL,
        supportURL: URL,
        terminationHandler: (() -> Void)? = nil,
        launchHandler: (() -> Void)? = nil
    ) {
        self.languageServerExecutableURL = languageServerExecutableURL
        self.managerDirectoryURL = managerDirectoryURL
        self.supportURL = supportURL
        self.terminationHandler = terminationHandler
        self.launchHandler = launchHandler
        projectPaths = []
        process = Process()
        transport = IOTransport()

        process.standardInput = transport.stdinPipe
        process.standardOutput = transport.stdoutPipe
        process.standardError = transport.stderrPipe

        process.executableURL = languageServerExecutableURL

        let isEnterpriseMode = UserDefaults.shared.value(for: \.codeiumEnterpriseMode)
        var apiServerUrl = "https://server.codeium.com"
        if isEnterpriseMode, UserDefaults.shared.value(for: \.codeiumApiUrl) != "" {
            apiServerUrl = UserDefaults.shared.value(for: \.codeiumApiUrl)
        }

        process.arguments = [
            "--api_server_url",
            apiServerUrl,
            "--manager_dir",
            managerDirectoryURL.path,
            "--enable_chat_web_server",
            "--enable_chat_client",
        ]

        if isEnterpriseMode {
            process.arguments?.append("--enterprise_mode")
            process.arguments?.append("--portal_url")
            process.arguments?.append(UserDefaults.shared.value(for: \.codeiumPortalUrl))
        }

        let indexEnabled = UserDefaults.shared.value(for: \.codeiumIndexEnabled)
        if indexEnabled {
            let indexingMaxFileSize = UserDefaults.shared.value(for: \.codeiumIndexingMaxFileSize)
            if indexEnabled {
                process.arguments?.append("--enable_local_search")
                process.arguments?.append("--enable_index_service")
                process.arguments?.append("--search_max_workspace_file_count")
                process.arguments?.append("\(indexingMaxFileSize)")
                Logger.codeium.info("Indexing Enabled")
            }
        }

        process.currentDirectoryURL = supportURL

        process.terminationHandler = { [weak self] task in
            self?.processTerminated(task)
        }
    }

    func start() {
        guard !process.isRunning else { return }
        do {
            try process.run()

            Task { @MainActor in
                func findPort() -> String? {
                    // find a file in managerDirectoryURL whose name looks like a port, return the
                    // name if found
                    let fileManager = FileManager.default
                    guard let filePaths = try? fileManager
                        .contentsOfDirectory(atPath: managerDirectoryURL.path) else { return nil }
                    for path in filePaths {
                        let filename = URL(fileURLWithPath: path).lastPathComponent
                        if filename.range(
                            of: #"^\d+$"#,
                            options: .regularExpression
                        ) != nil {
                            return filename
                        }
                    }
                    return nil
                }

                try await Task.sleep(nanoseconds: 2_000_000)
                var waited = 0

                while true {
                    waited += 1
                    if let port = findPort() {
                        finishStarting(port: port)
                        return
                    }
                    if waited >= 60 {
                        process.terminate()
                        return
                    }
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        } catch {
            Logger.codeium.error(error.localizedDescription)
            processTerminated(process)
        }
    }

    deinit {
        process.terminationHandler = nil
        if process.isRunning {
            process.terminate()
        }
        transport.close()
    }

    private func processTerminated(_: Process) {
        transport.close()
        terminationHandler?()
    }

    private func finishStarting(port: String) {
        Logger.codeium.info("Language server started.")
        self.port = port
        launchHandler?()
    }

    func terminate() {
        process.terminationHandler = nil
        if process.isRunning {
            process.terminate()
        }
        transport.close()
    }
}

extension CodeiumLanguageServer: CodeiumLSP {
    func sendRequest<E>(_ request: E) async throws -> E.Response where E: CodeiumRequestType {
        guard let port else { throw CancellationError() }

        let request = request.makeURLRequest(server: "http://127.0.0.1:\(port)")
        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 200 {
            do {
                let response = try JSONDecoder().decode(E.Response.self, from: data)
                return response
            } catch {
                if UserDefaults.shared.value(for: \.codeiumVerboseLog) {
                    dump(error)
                    Logger.codeium.error(error.localizedDescription)
                }
                throw error
            }
        } else {
            do {
                let error = try JSONDecoder().decode(CodeiumResponseError.self, from: data)
                if error.code == "aborted" {
                    if error.message.contains("is too old") {
                        throw CodeiumError.languageServerOutdated
                    }
                    throw error
                }
                throw CancellationError()
            } catch {
                if UserDefaults.shared.value(for: \.codeiumVerboseLog) {
                    Logger.codeium.error(error.localizedDescription)
                }
                throw error
            }
        }
    }

    func updateIndexing() async {
        let indexEnabled = UserDefaults.shared.value(for: \.codeiumIndexEnabled)
        if !indexEnabled {
            return
        }

        let currentProjectPaths = await getProjectPaths()

        // Add all workspaces that are in the currentProjectPaths but not in the previous project
        // paths
        for currentProjectPath in currentProjectPaths {
            if !projectPaths.contains(currentProjectPath) && FileManager.default
                .fileExists(atPath: currentProjectPath)
            {
                _ = try? await sendRequest(CodeiumRequest.AddTrackedWorkspace(requestBody: .init(
                    workspace: currentProjectPath
                )))
            }
        }

        // Remove all workspaces that are in previous project paths but not in the
        // currentProjectPaths
        for projectPath in projectPaths {
            if !currentProjectPaths.contains(projectPath) && FileManager.default
                .fileExists(atPath: projectPath)
            {
                _ = try? await sendRequest(CodeiumRequest.RemoveTrackedWorkspace(requestBody: .init(
                    workspace: projectPath
                )))
            }
        }
        // These should be identical now
        projectPaths = currentProjectPaths
    }
}

final class IOTransport {
    public let stdinPipe: Pipe
    public let stdoutPipe: Pipe
    public let stderrPipe: Pipe
    private var closed: Bool
    private var queue: DispatchQueue

    public init() {
        stdinPipe = Pipe()
        stdoutPipe = Pipe()
        stderrPipe = Pipe()
        closed = false
        queue = DispatchQueue(label: "com.intii.CopilotForXcode.IOTransport")

        setupFileHandleHandlers()
    }

    public func write(_ data: Data) {
        if closed {
            return
        }

        let fileHandle = stdinPipe.fileHandleForWriting

        queue.async {
            fileHandle.write(data)
        }
    }

    public func close() {
        queue.sync {
            if self.closed {
                return
            }

            self.closed = true

            [stdoutPipe, stderrPipe, stdinPipe].forEach { pipe in
                pipe.fileHandleForWriting.closeFile()
                pipe.fileHandleForReading.closeFile()
            }
        }
    }

    private func setupFileHandleHandlers() {
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData

            guard !data.isEmpty else {
                return
            }

            if UserDefaults.shared.value(for: \.codeiumVerboseLog) {
                self?.forwardDataToHandler(data)
            }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData

            guard !data.isEmpty else {
                return
            }

            if UserDefaults.shared.value(for: \.codeiumVerboseLog) {
                self?.forwardErrorDataToHandler(data)
            }
        }
    }

    private func forwardDataToHandler(_ data: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }

            if self.closed {
                return
            }

            if let string = String(bytes: data, encoding: .utf8) {
                Logger.codeium.info("stdout: \(string)")
            }
        }
    }

    private func forwardErrorDataToHandler(_ data: Data) {
        queue.async {
            if let string = String(bytes: data, encoding: .utf8) {
                Logger.codeium.error("stderr: \(string)")
            }
        }
    }
}

class WorkspaceParser: NSObject, XMLParserDelegate {
    var projectPaths: [String] = []
    var workspaceFileURL: URL
    var workspaceBaseURL: URL

    init(workspaceFileURL: URL, workspaceBaseURL: URL) {
        self.workspaceFileURL = workspaceFileURL
        self.workspaceBaseURL = workspaceBaseURL
    }

    func parse() -> [String] {
        guard let parser = XMLParser(contentsOf: workspaceFileURL) else {
            print("Failed to create XML parser for file: \(workspaceFileURL.path)")
            return []
        }
        parser.delegate = self
        parser.parse()
        return projectPaths
    }

    // XMLParserDelegate methods
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        if elementName == "FileRef", let location = attributeDict["location"] {
            var project_path: String
            if location.starts(with: "group:") && pathEndsWithXcodeproj(location) {
                let curr_path = String(location.dropFirst("group:".count))
                guard let relative_project_url = URL(string: curr_path) else {
                    return
                }
                let relative_base_path = relative_project_url.deletingLastPathComponent()
                project_path = (
                    workspaceBaseURL
                        .appendingPathComponent(relative_base_path.relativePath)
                ).standardized.path
            } else if location.starts(with: "absolute:") && pathEndsWithXcodeproj(location) {
                let abs_url = URL(fileURLWithPath: String(location.dropFirst("absolute:".count)))
                project_path = abs_url.deletingLastPathComponent().standardized.path
            } else {
                return
            }
            if FileManager.default.fileExists(atPath: project_path) {
                projectPaths.append(project_path)
            }
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("Failed to parse XML: \(parseError.localizedDescription)")
    }

    func pathEndsWithXcodeproj(_ path: String) -> Bool {
        return path.hasSuffix(".xcodeproj")
    }
}

public func getProjectPaths() async -> [String] {
    guard let workspaceURL = await XcodeInspector.shared.safe.realtimeActiveWorkspaceURL else {
        return []
    }

    let workspacebaseURL = workspaceURL.deletingLastPathComponent()

    let workspaceContentsURL = workspaceURL.appendingPathComponent("contents.xcworkspacedata")

    let parser = WorkspaceParser(
        workspaceFileURL: workspaceContentsURL,
        workspaceBaseURL: workspacebaseURL
    )
    let absolutePaths = parser.parse()
    return absolutePaths
}


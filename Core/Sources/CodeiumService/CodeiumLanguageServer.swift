import Foundation
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import Logger

protocol CodeiumLSP {
    func sendRequest<E: CodeiumRequestType>(_ endpoint: E) async throws -> E.Response
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
        process = Process()
        transport = IOTransport()

        process.standardInput = transport.stdinPipe
        process.standardOutput = transport.stdoutPipe
        process.standardError = transport.stderrPipe

        process.executableURL = languageServerExecutableURL

        process.arguments = [
            "--api_server_host",
            "server.codeium.com",
            "--api_server_port",
            "443",
            "--manager_dir",
            managerDirectoryURL.path,
        ]

        process.currentDirectoryURL = supportURL

        process.terminationHandler = { [weak self] task in
            self?.processTerminated(task)
        }
    }

    func start() {
        guard !process.isRunning else { return }
        port = nil
        do {
            try process.run()

            Task {
                func findPort() -> String? {
                    // find a file in managerDirectoryURL whose name looks like a port, return the
                    // name if found
                    let fileManager = FileManager.default
                    let enumerator = fileManager.enumerator(
                        at: managerDirectoryURL,
                        includingPropertiesForKeys: nil
                    )
                    while let fileURL = enumerator?.nextObject() as? URL {
                        if fileURL.lastPathComponent.range(
                            of: #"^\d+$"#,
                            options: .regularExpression
                        ) != nil {
                            return fileURL.lastPathComponent
                        }
                    }
                    return nil
                }

                try await Task.sleep(nanoseconds: 2_000_000)
                port = findPort()
                var waited = 0

                while true {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    waited += 1
                    if let port = findPort() {
                        finishStarting(port: port)
                        return
                    }
                    if waited >= 60 {
                        process.terminate()
                    }
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
                dump(error)
                Logger.codeium.error(error.localizedDescription)
                throw error
            }
        } else {
            do {
                let error = try JSONDecoder().decode(CodeiumResponseError.self, from: data)
                Logger.codeium.error(error.message)
                throw CancellationError()
            } catch {
                Logger.codeium.error(error.localizedDescription)
                throw error
            }
        }
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
        stdoutPipe.fileHandleForReading.readabilityHandler = { [unowned self] handle in
            let data = handle.availableData

            guard !data.isEmpty else {
                return
            }

            #if DEBUG
            self.forwardDataToHandler(data)
            #endif
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [unowned self] handle in
            let data = handle.availableData

            guard !data.isEmpty else {
                return
            }

            #if DEBUG
            self.forwardErrorDataToHandler(data)
            #endif
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


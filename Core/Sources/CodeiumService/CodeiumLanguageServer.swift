import Foundation
import JSONRPC
import LanguageClient
import LanguageServerProtocol

protocol CodeiumLSP {
    func sendRequest<E: CodeiumRequestType>(_ endpoint: E) async throws -> E.Response
}

class CodeiumLanguageServer: CodeiumLSP {
    let languageServerExecutableURL: URL
    let managerDirectoryURL: URL
    let supportURL: URL
    let process: Process
    let transport: StdioDataTransport
    var terminationHandler: (() -> Void)?
    var launchHandler: (() -> Void)?
    var port: String?

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
        transport = StdioDataTransport()

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
                    port = findPort()
                    if port != nil { break }
                    if waited >= 60 {
                        process.terminate()
                    }
                }
            }
        } catch {
            print("start: ", error)
            processTerminated(process)
        }
    }

    deinit {
        process.terminationHandler = nil
        process.terminate()
        transport.close()
    }

    private func processTerminated(_: Process) {
        transport.close()
        terminationHandler?()
    }

    func handleFileEvent(_ event: FileEvent) {
        switch event.type {
        case .created:
            let fileURL = URL(fileURLWithPath: event.uri)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
               !isDirectory.boolValue
            {
                let portName = fileURL.lastPathComponent
                print("set port", portName)
                if port == nil {
                    port = portName
                }
            }
        default:
            break
        }
    }

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
                throw error
            }
        } else {
            do {
                let error = try JSONDecoder().decode(CodeiumResponseError.self, from: data)
                throw error
            } catch {
                print(String(data: data, encoding: .utf8))
                throw error
            }
        }
    }
}


import Foundation
import PythonKit

final class PythonThread: Thread {
    static let shared = {
        let thread = PythonThread(
            target: PythonThread.self,
            selector: #selector(PythonThread.setup),
            object: nil
        )
        thread.name = "Python Thread"
        thread.stackSize = 1_048_576 // so that langchain can be correctly imported.
        return thread
    }()

    @objc static func setup() {
        CFRunLoopRun()
    }

    @objc static func runPythonJob(_ job: PythonJob) {
        job.run()
    }

    func runPython(_ closure: @escaping () -> Void) {
        if !isExecuting {
            start()
        }

        if Thread.current.isEqual(self) {
            closure()
        } else {
            PythonThread.perform(
                #selector(PythonThread.runPythonJob),
                on: self,
                with: PythonJob(closure: closure),
                waitUntilDone: false
            )
        }
    }

    func runPythonAndWait<T>(_ closure: @escaping () throws -> T) throws -> T {
        if !isExecuting {
            start()
        }

        if Thread.current.isEqual(self) {
            return try closure()
        } else {
            let job = PythonJob(closure: closure)
            PythonThread.perform(
                #selector(PythonThread.runPythonJob),
                on: self,
                with: job,
                waitUntilDone: true
            )
            guard let result = job.result else {
                throw FailedToGetPythonJobResultError()
            }
            switch result {
            case let .success(value):
                if let value = value as? T {
                    return value
                } else {
                    throw FailedToGetPythonJobResultError()
                }
            case let .failure(error):
                throw error
            }
        }
    }
}

struct FailedToGetPythonJobResultError: Error, LocalizedError {
    var errorDescription: String? {
        "Failed to get PythonJob result."
    }
}

final class PythonJob: NSObject {
    let closure: () throws -> Any
    var result: Result<Any, Error>?
    init(closure: @escaping () throws -> Any) {
        self.closure = closure
    }

    func run() {
        result = Result(catching: closure)
    }
}


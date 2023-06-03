import Foundation
import PythonKit

public struct ReadablePythonError: Error, LocalizedError {
    public var error: PythonError

    public init(_ error: PythonError) {
        self.error = error
    }

    public var errorDescription: String? {
        switch error {
        case let .exception(object, _):
            return "\(object)"
        case let .invalidCall(object):
            return "Invalid call: \(object)"
        case let .invalidModule(module):
            return "Invalid module: \(module)"
        }
    }
}

public func withReadableThrowingPython<T>(
    _ closure: () throws -> T
) throws -> T {
    do {
        return try closure()
    } catch let error as PythonError {
        throw ReadablePythonError(error)
    } catch {
        throw error
    }
}


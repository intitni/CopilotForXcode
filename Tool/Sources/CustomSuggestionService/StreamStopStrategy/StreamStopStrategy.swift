import Foundation

public enum StreamStopStrategyResult {
    case `continue`
    case stop(appendingNewContent: Bool)
}

public protocol StreamStopStrategy {
    func shouldStop(existedLines: [String], currentLine: String, proposedLineLimit: Int)
        -> StreamStopStrategyResult
}


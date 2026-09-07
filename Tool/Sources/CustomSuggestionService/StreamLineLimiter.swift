import Foundation
import Preferences

final class StreamLineLimiter {
    public private(set) var result = ""
    private var currentLine = ""
    private var existedLines = [String]()
    private let lineLimit: Int
    private let strategy: any StreamStopStrategy

    enum PushResult: Equatable {
        case `continue`
        case finish(String)
    }

    init(
        lineLimit: Int = UserDefaults.shared.value(for: \.customSuggestionMaxLines),
        strategy: any StreamStopStrategy
    ) {
        self.lineLimit = lineLimit
        self.strategy = strategy
    }

    func push(_ token: String) -> PushResult {
        currentLine.append(token)
        if let newLine = currentLine.last(where: { $0.isNewline }) {
            let lines = currentLine
                .breakLines(proposedLineEnding: String(newLine), appendLineBreakToLastLine: false)
            let (newLines, lastLine) = lines.headAndTail
            existedLines.append(contentsOf: newLines)
            currentLine = lastLine ?? ""
        }

        let stopResult = if lineLimit <= 0 {
            StreamStopStrategyResult.continue
        } else {
            strategy.shouldStop(
                existedLines: existedLines,
                currentLine: currentLine,
                proposedLineLimit: lineLimit
            )
        }

        switch stopResult {
        case .continue:
            result.append(token)
            return .continue
        case let .stop(appendingNewContent):
            if appendingNewContent {
                result.append(token)
            }
            return .finish(result)
        }
    }
}

extension Array {
    var headAndTail: ([Element], Element?) {
        guard let tail = last else { return ([], nil) }
        return (Array(dropLast()), tail)
    }
}


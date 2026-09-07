import Foundation

public struct OpeningTagBasedStreamStopStrategy: StreamStopStrategy {
    public let openingTag: String
    public let toleranceIfNoOpeningTagFound: Int

    public init(openingTag: String, toleranceIfNoOpeningTagFound: Int) {
        self.openingTag = openingTag
        self.toleranceIfNoOpeningTagFound = toleranceIfNoOpeningTagFound
    }

    public func shouldStop(
        existedLines: [String],
        currentLine: String,
        proposedLineLimit: Int
    ) -> StreamStopStrategyResult {
        if let index = existedLines.firstIndex(where: { $0.contains(openingTag) }) {
            if existedLines.count - index - 1 >= proposedLineLimit {
                return .stop(appendingNewContent: true)
            }
            return .continue
        } else {
            if existedLines.count >= proposedLineLimit + toleranceIfNoOpeningTagFound {
                return .stop(appendingNewContent: true)
            } else {
                return .continue
            }
        }
    }
}


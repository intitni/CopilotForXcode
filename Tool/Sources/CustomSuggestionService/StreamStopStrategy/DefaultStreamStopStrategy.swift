public struct DefaultStreamStopStrategy: StreamStopStrategy {
    public init() {}

    public func shouldStop(
        existedLines: [String],
        currentLine: String,
        proposedLineLimit: Int
    ) -> StreamStopStrategyResult {
        if existedLines.count >= proposedLineLimit {
            return .stop(appendingNewContent: true)
        }
        return .continue
    }
}


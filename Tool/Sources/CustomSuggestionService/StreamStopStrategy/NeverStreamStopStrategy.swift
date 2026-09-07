public struct NeverStreamStopStrategy: StreamStopStrategy {
    public init() {}

    public func shouldStop(
        existedLines: [String],
        currentLine: String,
        proposedLineLimit: Int
    ) -> StreamStopStrategyResult {
        .continue
    }
}


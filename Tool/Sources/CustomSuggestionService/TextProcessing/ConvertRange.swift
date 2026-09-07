import CopilotForXcodeKit
import Foundation

public func convertRangeToCursorRange(
    _ range: ClosedRange<Int>,
    in lines: [String]
) -> CursorRange {
    guard !lines.isEmpty else { return CursorRange(start: .zero, end: .zero) }
    var countS = 0
    var countE = 0
    var cursorRange = CursorRange(start: .zero, end: .outOfScope)
    for (i, line) in lines.enumerated() {
        // The range is counted in UTF8, which causes line endings like \r\n to be of length 2.
        let lineEndingAddition = line.lineEnding.utf8.count - 1
        if countS <= range.lowerBound,
           range.lowerBound < countS + line.count + lineEndingAddition
        {
            cursorRange.start = .init(line: i, character: range.lowerBound - countS)
        }
        if countE <= range.upperBound,
           range.upperBound < countE + line.count + lineEndingAddition
        {
            cursorRange.end = .init(line: i, character: range.upperBound - countE)
            break
        }
        countS += line.count + lineEndingAddition
        countE += line.count + lineEndingAddition
    }
    if cursorRange.end == .outOfScope {
        cursorRange.end = .init(line: lines.endIndex - 1, character: lines.last?.count ?? 0)
    }
    return cursorRange
}


import Foundation

public extension String {
    /// The line ending of the string.
    var lineEnding: Character? {
        last(where: \.isNewline)
    }

    /// Break a string into lines.
    func breakLines(
        proposedLineEnding: String? = nil,
        appendLineBreakToLastLine: Bool = false
    ) -> [String] {
        let lineEnding = proposedLineEnding ?? String(lineEnding ?? "\n")
        let lines = split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var all = [String]()
        for (index, line) in lines.enumerated() {
            if !appendLineBreakToLastLine, index == lines.endIndex - 1 {
                all.append(String(line))
            } else {
                all.append(String(line) + String(lineEnding))
            }
        }
        return all
    }
}


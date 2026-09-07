import Foundation

public extension String {
    /// The line ending of the string.
    ///
    /// We are pretty safe to just check the last character here, in most case, a line ending
    /// will be in the end of the string.
    ///
    /// For other situations, we can assume that they are "\n".
    var lineEnding: Character {
        if let last, last.isNewline { return last }
        return "\n"
    }

    func splitByNewLine(
        omittingEmptySubsequences: Bool = true,
        fast: Bool = true
    ) -> [Substring] {
        if fast {
            let lineEndingInText = lineEnding
            return split(
                separator: lineEndingInText,
                omittingEmptySubsequences: omittingEmptySubsequences
            )
        }
        return split(
            omittingEmptySubsequences: omittingEmptySubsequences,
            whereSeparator: \.isNewline
        )
    }

    /// Break a string into lines.
    func breakLines(
        proposedLineEnding: String? = nil,
        appendLineBreakToLastLine: Bool = false
    ) -> [String] {
        let lineEndingInText = lineEnding
        let lineEnding = proposedLineEnding ?? String(lineEndingInText)
        // Split on character for better performance.
        let lines = split(separator: lineEndingInText, omittingEmptySubsequences: false)
        var all = [String]()
        for (index, line) in lines.enumerated() {
            if !appendLineBreakToLastLine, index == lines.endIndex - 1 {
                all.append(String(line))
            } else {
                all.append(String(line) + lineEnding)
            }
        }
        return all
    }
}


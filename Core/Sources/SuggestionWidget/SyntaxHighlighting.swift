import AppKit
import Foundation
import Highlightr
import SwiftUI
import XPCShared

func highlightedCodeBlock(
    code: String,
    language: String,
    brightMode: Bool,
    fontSize: Double
) -> NSAttributedString {
    var language = language
    if language == "objective-c" {
        language = "objectivec"
    }
    func unhighlightedCode() -> NSAttributedString {
        return NSAttributedString(
            string: code,
            attributes: [
                .foregroundColor: brightMode ? NSColor.black : NSColor.white,
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            ]
        )
    }
    guard let highlighter = Highlightr() else {
        return unhighlightedCode()
    }
    highlighter.setTheme(to: brightMode ? "xcode" : "atom-one-dark")
    highlighter.theme.setCodeFont(.monospacedSystemFont(ofSize: fontSize, weight: .regular))
    guard let formatted = highlighter.highlight(code, as: language) else {
        return unhighlightedCode()
    }
    if formatted.string == "undefined" {
        return unhighlightedCode()
    }
    return formatted
}

func highlighted(
    code: String,
    language: String,
    brightMode: Bool,
    droppingLeadingSpaces: Bool
) -> (code: [NSAttributedString], commonLeadingSpaceCount: Int) {
    let formatted = highlightedCodeBlock(
        code: code,
        language: language,
        brightMode: brightMode,
        fontSize: 13
    )
    let middleDotColor = brightMode
        ? NSColor.black.withAlphaComponent(0.1)
        : NSColor.white.withAlphaComponent(0.1)
    return convertToCodeLines(
        formatted,
        middleDotColor: middleDotColor,
        droppingLeadingSpaces: droppingLeadingSpaces
    )
}

func convertToCodeLines(
    _ formattedCode: NSAttributedString,
    middleDotColor: NSColor,
    droppingLeadingSpaces: Bool
) -> (code: [NSAttributedString], commonLeadingSpaceCount: Int) {
    let input = formattedCode.string
    func isEmptyLine(_ line: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #"^\s*\n?$"#) else { return false }
        if regex.firstMatch(
            in: line,
            options: [],
            range: NSMakeRange(0, line.utf16.count)
        ) != nil {
            return true
        }
        return false
    }

    let separatedInput = input.components(separatedBy: "\n")
    let commonLeadingSpaceCount = {
        if !droppingLeadingSpaces { return 0 }
        let splitted = separatedInput
        var result = 0
        outerLoop: for i in [4, 8, 12, 16, 20] {
            for line in splitted {
                if isEmptyLine(line) { continue }
                if i >= line.count { break outerLoop }
                let targetIndex = line.index(line.startIndex, offsetBy: i - 1)
                if line[targetIndex] != " " { break outerLoop }
            }
            result = i
        }
        return result
    }()
    var output = [NSAttributedString]()
    var start = 0
    for sub in separatedInput {
        let range = NSMakeRange(start, sub.utf16.count)
        let attributedString = formattedCode.attributedSubstring(from: range)
        let mutable = NSMutableAttributedString(attributedString: attributedString)

        // remove leading spaces
        if commonLeadingSpaceCount > 0 {
            let leadingSpaces = String(repeating: " ", count: commonLeadingSpaceCount)
            if isEmptyLine(mutable.string) {
                mutable.mutableString.setString("")
            } else if mutable.string.hasPrefix(leadingSpaces) {
                mutable.replaceCharacters(
                    in: NSRange(location: 0, length: commonLeadingSpaceCount),
                    with: ""
                )
            }
        }

        // use regex to replace all spaces to a middle dot
        do {
            let regex = try NSRegularExpression(pattern: #"\s*"#, options: [])
            let result = regex.matches(
                in: mutable.string,
                range: NSRange(location: 0, length: mutable.mutableString.length)
            )
            for r in result {
                let range = r.range
                mutable.replaceCharacters(
                    in: range,
                    with: String(repeating: "·", count: range.length)
                )
                mutable.addAttributes([
                    .foregroundColor: middleDotColor,
                ], range: range)
            }
        } catch {}
        output.append(mutable)
        start += range.length + 1
    }
    return (output, commonLeadingSpaceCount)
}

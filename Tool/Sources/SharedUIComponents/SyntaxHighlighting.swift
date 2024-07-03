import AppKit
import Foundation
import Highlightr
import SuggestionBasic
import SwiftUI

public enum CodeHighlighting {
    public static func highlightedCodeBlock(
        code: String,
        language: String,
        scenario: String,
        brightMode: Bool,
        font: NSFont
    ) -> NSAttributedString {
        var language = language
        // Workaround: Highlightr uses a different identifier for Objective-C.
        if language.lowercased().hasPrefix("objective"), language.lowercased().hasSuffix("c") {
            language = "objectivec"
        }
        func unhighlightedCode() -> NSAttributedString {
            return NSAttributedString(
                string: code,
                attributes: [
                    .foregroundColor: brightMode ? NSColor.black : NSColor.white,
                    .font: font,
                ]
            )
        }
        guard let highlighter = Highlightr() else {
            return unhighlightedCode()
        }
        highlighter.setTheme(to: {
            let mode = brightMode ? "light" : "dark"
            if scenario.isEmpty {
                return mode
            }
            return "\(scenario)-\(mode)"
        }())
        highlighter.theme.setCodeFont(font)
        guard let formatted = highlighter.highlight(code, as: language) else {
            return unhighlightedCode()
        }
        if formatted.string == "undefined" {
            return unhighlightedCode()
        }
        return formatted
    }

    public static func highlighted(
        code: String,
        language: String,
        scenario: String,
        brightMode: Bool,
        droppingLeadingSpaces: Bool,
        font: NSFont,
        replaceSpacesWithMiddleDots: Bool = true
    ) -> (code: [NSAttributedString], commonLeadingSpaceCount: Int) {
        let formatted = highlightedCodeBlock(
            code: code,
            language: language,
            scenario: scenario,
            brightMode: brightMode,
            font: font
        )
        let middleDotColor = brightMode
            ? NSColor.black.withAlphaComponent(0.1)
            : NSColor.white.withAlphaComponent(0.1)
        return convertToCodeLines(
            formatted,
            middleDotColor: middleDotColor,
            droppingLeadingSpaces: droppingLeadingSpaces,
            replaceSpacesWithMiddleDots: replaceSpacesWithMiddleDots
        )
    }

    public static func convertToCodeLines(
        _ formattedCode: NSAttributedString,
        middleDotColor: NSColor,
        droppingLeadingSpaces: Bool,
        replaceSpacesWithMiddleDots: Bool = true
    ) -> (code: [NSAttributedString], commonLeadingSpaceCount: Int) {
        let input = formattedCode.string
        func isEmptyLine(_ line: String) -> Bool {
            if line.isEmpty { return true }
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

        let separatedInput = input.splitByNewLine(omittingEmptySubsequences: false)
            .map { String($0) }
        let commonLeadingSpaceCount = {
            if !droppingLeadingSpaces { return 0 }
            let split = separatedInput
            var result = 0
            outerLoop: for i in stride(from: 40, through: 4, by: -4) {
                for line in split {
                    if isEmptyLine(line) { continue }
                    if i >= line.count { continue outerLoop }
                    if !line.hasPrefix(.init(repeating: " ", count: i)) { continue outerLoop }
                }
                result = i
                break
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
                if mutable.string.hasPrefix(leadingSpaces) {
                    mutable.replaceCharacters(
                        in: NSRange(location: 0, length: commonLeadingSpaceCount),
                        with: ""
                    )
                } else if isEmptyLine(mutable.string) {
                    mutable.mutableString.setString("")
                }
            }

            if replaceSpacesWithMiddleDots {
                // use regex to replace all spaces to a middle dot
                do {
                    let regex = try NSRegularExpression(pattern: "[ ]*", options: [])
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
            }
            output.append(mutable)
            start += range.length + 1
        }
        return (output, commonLeadingSpaceCount)
    }
}


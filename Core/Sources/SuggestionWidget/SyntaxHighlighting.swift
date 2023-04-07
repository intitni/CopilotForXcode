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

func highlighted(code: String, language: String, brightMode: Bool) -> [NSAttributedString] {
    let formatted = highlightedCodeBlock(
        code: code,
        language: language,
        brightMode: brightMode,
        fontSize: 13
    )
    let middleDotColor = brightMode
        ? NSColor.black.withAlphaComponent(0.1)
        : NSColor.white.withAlphaComponent(0.1)
    return convertToCodeLines(formatted, middleDotColor: middleDotColor)
}

private func convertToCodeLines(
    _ formattedCode: NSAttributedString,
    middleDotColor: NSColor
) -> [NSAttributedString] {
    let input = formattedCode.string
    let separatedInput = input.components(separatedBy: "\n")
    var output = [NSAttributedString]()
    var start = 0
    for sub in separatedInput {
        let range = NSMakeRange(start, sub.utf16.count)
        let attributedString = formattedCode.attributedSubstring(from: range)
        let mutable = NSMutableAttributedString(attributedString: attributedString)
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
        output.append(mutable)
        start += range.length + 1
    }
    return output
}

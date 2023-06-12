import AppKit
import Foundation
import Highlightr
import Splash
import SwiftUI
import XPCShared

func highlightedCodeBlock(
    code: String,
    language: String,
    brightMode: Bool,
    fontSize: Double
) -> NSAttributedString {
    switch language {
    case "swift":
        let plainTextColor = brightMode
            ? .black
            : #colorLiteral(red: 0.6509803922, green: 0.6980392157, blue: 0.7529411765, alpha: 1)
        let highlighter =
            SyntaxHighlighter(
                format: AttributedStringOutputFormat(theme: .init(
                    font: .init(size: 14),
                    plainTextColor: plainTextColor,
                    tokenColors: brightMode
                        ? [
                            .keyword: #colorLiteral(red: 0.6078431373, green: 0.137254902, blue: 0.5764705882, alpha: 1),
                            .string: #colorLiteral(red: 0.1371159852, green: 0.3430536985, blue: 0.362406373, alpha: 1),
                            .type: #colorLiteral(red: 0.2456904352, green: 0.5002114773, blue: 0.5297455192, alpha: 1),
                            .call: #colorLiteral(red: 0.1960784314, green: 0.4274509804, blue: 0.4549019608, alpha: 1),
                            .number: #colorLiteral(red: 0.4385872483, green: 0.4995297194, blue: 0.5483990908, alpha: 1),
                            .comment: #colorLiteral(red: 0.3647058824, green: 0.4235294118, blue: 0.4745098039, alpha: 1),
                            .property: #colorLiteral(red: 0.1960784314, green: 0.4274509804, blue: 0.4549019608, alpha: 1),
                            .dotAccess: #colorLiteral(red: 0.1960784314, green: 0.4274509804, blue: 0.4549019608, alpha: 1),
                            .preprocessing: #colorLiteral(red: 0.3921568627, green: 0.2196078431, blue: 0.1254901961, alpha: 1),
                        ] : [
                            .keyword: #colorLiteral(red: 0.8258609176, green: 0.5708742738, blue: 0.8922662139, alpha: 1),
                            .string: #colorLiteral(red: 0.6253595352, green: 0.7963448763, blue: 0.5427476764, alpha: 1),
                            .type: #colorLiteral(red: 0.9221783876, green: 0.7978314757, blue: 0.5575165749, alpha: 1),
                            .call: #colorLiteral(red: 0.4466812611, green: 0.742190659, blue: 0.9515134692, alpha: 1),
                            .number: #colorLiteral(red: 0.8620631099, green: 0.6468816996, blue: 0.4395158887, alpha: 1),
                            .comment: #colorLiteral(red: 0.4233166873, green: 0.4612616301, blue: 0.5093258619, alpha: 1),
                            .property: #colorLiteral(red: 0.906378448, green: 0.5044228435, blue: 0.5263597369, alpha: 1),
                            .dotAccess: #colorLiteral(red: 0.906378448, green: 0.5044228435, blue: 0.5263597369, alpha: 1),
                            .preprocessing: #colorLiteral(red: 0.3776347041, green: 0.8792117238, blue: 0.4709561467, alpha: 1),
                        ]
                ))
            )
        let formatted = NSMutableAttributedString(attributedString: highlighter.highlight(code))
        formatted.addAttributes(
            [.font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)],
            range: NSRange(location: 0, length: formatted.length)
        )
        func leadingSpacesInCode(_ code: String) -> Int {
            var leadingSpaces = 0
            for char in code {
                if char == " " {
                    leadingSpaces += 1
                } else {
                    break
                }
            }
            return leadingSpaces
        }
        
        // Workaround: Splash has a bug that will insert an extra space at the beginning.
        let leadingSpaces = leadingSpacesInCode(code)
        let leadingSpacesFormatted = leadingSpacesInCode(formatted.string)
        let diff = leadingSpacesFormatted - leadingSpaces
        if diff > 0 {
            formatted.mutableString.replaceCharacters(
                in: .init(location: 0, length: diff),
                with: ""
            )
        }
        // End of workaround.
        
        return formatted
    default:
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
}

func highlighted(
    code: String,
    language: String,
    brightMode: Bool,
    droppingLeadingSpaces: Bool
) -> (code: [NSAttributedString], commonLeadingSpaceCount: Int) {
    var fontSize: Double = 13
    if let size = Double(UserDefaults.shared.value(for: \.codeFontSize)) {
        fontSize = size
    }
    let formatted = highlightedCodeBlock(
        code: code,
        language: language,
        brightMode: brightMode,
        fontSize: fontSize
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

    let separatedInput = input.components(separatedBy: "\n")
    let commonLeadingSpaceCount = {
        if !droppingLeadingSpaces { return 0 }
        let splitted = separatedInput
        var result = 0
        outerLoop: for i in [4, 8, 12, 16, 20, 24] {
            for line in splitted {
                if isEmptyLine(line) { continue }
                if i >= line.count { break outerLoop }
                if !line.hasPrefix(.init(repeating: " ", count: i)) { break outerLoop }
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
            if mutable.string.hasPrefix(leadingSpaces) {
                mutable.replaceCharacters(
                    in: NSRange(location: 0, length: commonLeadingSpaceCount),
                    with: ""
                )
            } else if isEmptyLine(mutable.string) {
                mutable.mutableString.setString("")
            }
        }

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
    return (output, commonLeadingSpaceCount)
}

import AppKit
import Foundation
import Highlightr
import Splash

func highlighted(code: String, language: String) -> [NSAttributedString] {
    switch language {
    case "swift":
        let plainTextColor = #colorLiteral(red: 0.6509803922, green: 0.6980392157, blue: 0.7529411765, alpha: 1)
        let highlighter =
            SyntaxHighlighter(
                format: AttributedStringOutputFormat(theme: .init(
                    font: .init(size: 14),
                    plainTextColor: plainTextColor,
                    tokenColors: [
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
            [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)],
            range: NSRange(location: 0, length: formatted.length)
        )
        return convertToCodeLines(formatted)
    default:
        var language = language
        if language == "objective-c" {
            language = "objectivec"
        }
        func unhighlightedCode() -> [NSAttributedString] {
            return convertToCodeLines(NSAttributedString(string: code, attributes: [.foregroundColor: NSColor.white]))
        }
        guard let highlighter = Highlightr() else {
            return unhighlightedCode()
        }
        highlighter.setTheme(to: "atom-one-dark")
        highlighter.theme.setCodeFont(.monospacedSystemFont(ofSize: 13, weight: .regular))
        guard let formatted = highlighter.highlight(code, as: language) else {
            return unhighlightedCode()
        }
        if formatted.string == "undefined" {
            return unhighlightedCode()
        }
        return convertToCodeLines(formatted)
    }
}

private func convertToCodeLines(_ formattedCode: NSAttributedString) -> [NSAttributedString] {
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
                    .foregroundColor: NSColor.white.withAlphaComponent(0.1),
                ], range: range)
            }
        } catch {}
        output.append(mutable)
        start += range.length + 1
    }
    return output
}

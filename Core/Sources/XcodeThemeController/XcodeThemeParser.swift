import Foundation
import Preferences

public struct XcodeTheme: Codable {
    public struct ThemeColor: Codable {
        public var red: Double
        public var green: Double
        public var blue: Double
        public var alpha: Double

        public var hexString: String {
            let red = Int(self.red * 255)
            let green = Int(self.green * 255)
            let blue = Int(self.blue * 255)
            let alpha = Int(self.alpha * 255)
            return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
        }
        
        var storable: StorableColor {
            .init(red: red, green: green, blue: blue, alpha: alpha)
        }
    }

    public var plainTextColor: ThemeColor
    public var commentColor: ThemeColor
    public var documentationMarkupColor: ThemeColor
    public var documentationMarkupKeywordColor: ThemeColor
    public var marksColor: ThemeColor
    public var stringsColor: ThemeColor
    public var charactersColor: ThemeColor
    public var numbersColor: ThemeColor
    public var regexLiteralsColor: ThemeColor
    public var regexLiteralNumbersColor: ThemeColor
    public var regexLiteralCaptureNamesColor: ThemeColor
    public var regexLiteralCharacterClassNamesColor: ThemeColor
    public var regexLiteralOperatorsColor: ThemeColor
    public var keywordsColor: ThemeColor
    public var preprocessorStatementsColor: ThemeColor
    public var urlsColor: ThemeColor
    public var attributesColor: ThemeColor
    public var typeDeclarationsColor: ThemeColor
    public var otherDeclarationsColor: ThemeColor
    public var projectClassNamesColor: ThemeColor
    public var projectFunctionAndMethodNamesColor: ThemeColor
    public var projectConstantsColor: ThemeColor
    public var projectTypeNamesColor: ThemeColor
    public var projectPropertiesAndGlobalsColor: ThemeColor
    public var projectPreprocessorMacrosColor: ThemeColor
    public var otherClassNamesColor: ThemeColor
    public var otherFunctionAndMethodNamesColor: ThemeColor
    public var otherConstantsColor: ThemeColor
    public var otherTypeNamesColor: ThemeColor
    public var otherPropertiesAndGlobalsColor: ThemeColor
    public var otherPreprocessorMacrosColor: ThemeColor
    public var headingColor: ThemeColor
    public var backgroundColor: ThemeColor
    public var selectionColor: ThemeColor
    public var cursorColor: ThemeColor
    public var currentLineColor: ThemeColor
    public var invisibleCharactersColor: ThemeColor
    public var debuggerConsolePromptColor: ThemeColor
    public var debuggerConsoleOutputColor: ThemeColor
    public var debuggerConsoleInputColor: ThemeColor
    public var executableConsoleOutputColor: ThemeColor
    public var executableConsoleInputColor: ThemeColor

    public func asHighlightJSTheme() -> String {
        buildHighlightJSTheme(self)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: ": ", with: ":")
            .replacingOccurrences(of: "} ", with: "}")
            .replacingOccurrences(of: " {", with: "{")
            .replacingOccurrences(of: ";}", with: "}")
            .replacingOccurrences(of: "  ", with: "")
    }
}

public extension XcodeTheme {
    /// Color scheme locations:
    /// ~/Library/Developer/Xcode/UserData/FontAndColorThemes/
    /// Xcode.app/Contents/SharedFrameworks/DVTUserInterfaceKit.framework/Versions/A/Resources/FontAndColorThemes
    init(fileURL: URL) throws {
        let parser = XcodeThemeParser()
        self = try parser.parse(fileURL: fileURL)
    }
}

struct XcodeThemeParser {
    enum Error: Swift.Error {
        case fileNotFound
        case invalidData
    }

    func parse(fileURL: URL) throws -> XcodeTheme {
        guard let data = try? Data(contentsOf: fileURL) else {
            throw Error.fileNotFound
        }

        if fileURL.pathExtension == "xccolortheme" {
            return try parseXCColorTheme(data)
        } else {
            throw Error.invalidData
        }
    }

    func parseXCColorTheme(_ data: Data) throws -> XcodeTheme {
        let plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: .mutableContainers,
            format: nil
        ) as? [String: Any]

        guard let theme = plist else { throw Error.invalidData }

        /// The source value is an `r g b a` string, for example: `0.5 0.5 0.2 1`
        func converColor(source: String) -> XcodeTheme.ThemeColor {
            let components = source.split(separator: " ")
            let red = (components[0] as NSString).doubleValue
            let green = (components[1] as NSString).doubleValue
            let blue = (components[2] as NSString).doubleValue
            let alpha = (components[3] as NSString).doubleValue
            return .init(red: red, green: green, blue: blue, alpha: alpha)
        }

        func getThemeValue(
            at path: [String],
            defaultValue: XcodeTheme.ThemeColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
        ) -> XcodeTheme.ThemeColor {
            guard !path.isEmpty else { return defaultValue }
            let keys = path.dropLast(1)
            var currentDict = theme
            for key in keys {
                guard let value = currentDict[key] as? [String: Any] else {
                    return defaultValue
                }
                currentDict = value
            }
            if let value = currentDict[path.last!] as? String {
                return converColor(source: value)
            }
            return defaultValue
        }

        let black = XcodeTheme.ThemeColor(red: 0, green: 0, blue: 0, alpha: 1)
        let white = XcodeTheme.ThemeColor(red: 1, green: 1, blue: 1, alpha: 1)

        let xcodeTheme = XcodeTheme(
            plainTextColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.plain"],
                defaultValue: black
            ),
            commentColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.comment"],
                defaultValue: black
            ),
            documentationMarkupColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.comment.doc"],
                defaultValue: black
            ),
            documentationMarkupKeywordColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.comment.doc.keyword"],
                defaultValue: black
            ),
            marksColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.mark"],
                defaultValue: black
            ),
            stringsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.string"],
                defaultValue: black
            ),
            charactersColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.character"],
                defaultValue: black
            ),
            numbersColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.number"],
                defaultValue: black
            ),
            regexLiteralsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.plain"],
                defaultValue: black
            ),
            regexLiteralNumbersColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.number"],
                defaultValue: black
            ),
            regexLiteralCaptureNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.plain"],
                defaultValue: black
            ),
            regexLiteralCharacterClassNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.plain"],
                defaultValue: black
            ),
            regexLiteralOperatorsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.plain"],
                defaultValue: black
            ),
            keywordsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.keyword"],
                defaultValue: black
            ),
            preprocessorStatementsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.preprocessor"],
                defaultValue: black
            ),
            urlsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.url"],
                defaultValue: black
            ),
            attributesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.attribute"],
                defaultValue: black
            ),
            typeDeclarationsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.declaration.type"],
                defaultValue: black
            ),
            otherDeclarationsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.declaration.other"],
                defaultValue: black
            ),
            projectClassNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.class"],
                defaultValue: black
            ),
            projectFunctionAndMethodNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.function"],
                defaultValue: black
            ),
            projectConstantsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.constant"],
                defaultValue: black
            ),
            projectTypeNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.type"],
                defaultValue: black
            ),
            projectPropertiesAndGlobalsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.variable"],
                defaultValue: black
            ),
            projectPreprocessorMacrosColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.macro"],
                defaultValue: black
            ),
            otherClassNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.class.system"],
                defaultValue: black
            ),
            otherFunctionAndMethodNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.function.system"],
                defaultValue: black
            ),
            otherConstantsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.constant.system"],
                defaultValue: black
            ),
            otherTypeNamesColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.type.system"],
                defaultValue: black
            ),
            otherPropertiesAndGlobalsColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.variable.system"],
                defaultValue: black
            ),
            otherPreprocessorMacrosColor: getThemeValue(
                at: ["DVTSourceTextSyntaxColors", "xcode.syntax.identifier.macro.system"],
                defaultValue: black
            ),
            headingColor: getThemeValue(
                at: ["DVTMarkupTextPrimaryHeadingColor"],
                defaultValue: black
            ),
            backgroundColor: getThemeValue(
                at: ["DVTSourceTextBackground"],
                defaultValue: white
            ),
            selectionColor: getThemeValue(
                at: ["DVTSourceTextSelectionColor"],
                defaultValue: black
            ),
            cursorColor: getThemeValue(
                at: ["DVTSourceTextInsertionPointColor"],
                defaultValue: black
            ),
            currentLineColor: getThemeValue(
                at: ["DVTSourceTextCurrentLineHighlightColor"],
                defaultValue: black
            ),
            invisibleCharactersColor: getThemeValue(
                at: ["DVTSourceTextInvisiblesColor"],
                defaultValue: black
            ),
            debuggerConsolePromptColor: getThemeValue(
                at: ["DVTConsoleDebuggerPromptTextColor"],
                defaultValue: black
            ),
            debuggerConsoleOutputColor: getThemeValue(
                at: ["DVTConsoleDebuggerOutputTextColor"],
                defaultValue: black
            ),
            debuggerConsoleInputColor: getThemeValue(
                at: ["DVTConsoleDebuggerInputTextColor"],
                defaultValue: black
            ),
            executableConsoleOutputColor: getThemeValue(
                at: ["DVTConsoleExectuableOutputTextColor"],
                defaultValue: black
            ),
            executableConsoleInputColor: getThemeValue(
                at: ["DVTConsoleExectuableInputTextColor"],
                defaultValue: black
            )
        )

        return xcodeTheme
    }
}


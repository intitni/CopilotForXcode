import Foundation

func buildHighlightJSTheme(_ theme: XcodeTheme) -> String {
    /// The source value is an `r g b a` string, for example: `0.5 0.5 0.2 1`
    
    return """
    .hljs {
      display: block;
      overflow-x: auto;
      padding: 0.5em;
      background: \(theme.backgroundColor.hexString);
      color: \(theme.plainTextColor.hexString);
    }
    .xml .hljs-meta {
      color: \(theme.marksColor.hexString);
    }
    .hljs-comment,
    .hljs-quote {
      color: \(theme.commentColor.hexString);
    }
    .hljs-tag,
    .hljs-keyword,
    .hljs-selector-tag,
    .hljs-literal,
    .hljs-name {
      color: \(theme.keywordsColor.hexString);
    }
    .hljs-attribute {
      color: \(theme.attributesColor.hexString);
    }
    .hljs-variable,
    .hljs-template-variable {
      color: \(theme.otherPropertiesAndGlobalsColor.hexString);
    }
    .hljs-code,
    .hljs-string,
    .hljs-meta-string {
      color: \(theme.stringsColor.hexString);
    }
    .hljs-regexp {
      color: \(theme.regexLiteralsColor.hexString);
    }
    .hljs-link {
      color: \(theme.urlsColor.hexString);
    }
    .hljs-title {
      color: \(theme.headingColor.hexString);
    }
    .hljs-symbol,
    .hljs-bullet {
      color: \(theme.attributesColor.hexString);
    }
    .hljs-number {
      color: \(theme.numbersColor.hexString);
    }
    .hljs-section {
      color: \(theme.marksColor.hexString);
    }
    .hljs-meta {
      color: \(theme.keywordsColor.hexString);
    }
    .hljs-type,
    .hljs-built_in,
    .hljs-builtin-name {
          color: \(theme.otherTypeNamesColor.hexString);
    }
    .hljs-class .hljs-title,
    .hljs-title .class_ {
      color: \(theme.typeDeclarationsColor.hexString);
    }
    .hljs-function .hljs-title,
    .hljs-title .function_ {
      color: \(theme.otherDeclarationsColor.hexString);
    }
    .hljs-params {
      color: \(theme.otherDeclarationsColor.hexString);
    }
    .hljs-attr {
      color: \(theme.attributesColor.hexString);
    }
    .hljs-subst {
      color: \(theme.plainTextColor.hexString);
    }
    .hljs-formula {
      background-color: \(theme.selectionColor.hexString);
      font-style: italic;
    }
    .hljs-addition {
      background-color: #baeeba;
    }
    .hljs-deletion {
      background-color: #ffc8bd;
    }
    .hljs-selector-id,
    .hljs-selector-class {
      color: \(theme.plainTextColor.hexString);
    }
    .hljs-doctag,
    .hljs-strong {
      font-weight: bold;
    }
    .hljs-emphasis {
      font-style: italic;
    }
    """
}


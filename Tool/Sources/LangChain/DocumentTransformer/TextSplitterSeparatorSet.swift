public struct TextSplitterSeparatorSet: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = String

    public var separators: [String]
    public init(arrayLiteral elements: String...) {
        separators = elements
    }

    public static var swift: TextSplitterSeparatorSet {
        [
            // Split macros, property wrappers, actor
            "\n@\\w+\\s",
            "\n#\\w+\\s",
            // Split scopes
            "\npublic ",
            "\nprivate ",
            "\nfileprivate ",
            "\nopen ",
            "\nfinal ",
            // Split along class definitions
            "\nclass ",
            "\nstruct ",
            "\nenum ",
            "\nextension ",
            "\nprotocol ",
            "\nactor ",
            // Split along function definitions
            "\nstatic ",
            "\nfunc ",
            "\ninit ",
            // Split along control flow statements
            "\nif ",
            "\nfor ",
            "\nwhile ",
            "\ndo ",
            "\nswitch ",
            "\ncase ",
            // Split by the normal type of lines
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var cpp: TextSplitterSeparatorSet {
        [
            // Split along class definitions
            "\nclass ",
            // Split along function definitions
            "\nvoid ",
            "\nint ",
            "\nfloat ",
            "\ndouble ",
            // Split along control flow statements
            "\nif ",
            "\nfor ",
            "\nwhile ",
            "\nswitch ",
            "\ncase ",
            // Split by the normal type of lines
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var objectiveC: TextSplitterSeparatorSet {
        [
            // Split along interface declaration
            "\n@interface ",
            "\n@implementation ",
            "\n@typedef ",
            "\n@enum ",
            "\n@class ",
            // Property
            "\n@property ",
            // Split along function definitions
            "\n- (",
            "\n+ (",
            // Split along control flow statements
            "\nif ",
            "\nfor ",
            "\nwhile ",
            "\nswitch ",
            "\ncase ",
            // Split by the normal type of lines
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var go: TextSplitterSeparatorSet {
        [
            // Split along function definitions
            "\nfunc ",
            "\nvar ",
            "\nconst ",
            "\ntype ",
            // Split along control flow statements
            "\nif ",
            "\nfor ",
            "\nswitch ",
            "\ncase ",
            // Split by the normal type of lines
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var java: TextSplitterSeparatorSet {
        [
            // Split along class definitions
            "\nclass ",
            // Split along method definitions
            "\npublic ",
            "\nprotected ",
            "\nprivate ",
            "\nstatic ",
            // Split along control flow statements
            "\nif ",
            "\nfor ",
            "\nwhile ",
            "\nswitch ",
            "\ncase ",
            // Split by the normal type of lines
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var php: TextSplitterSeparatorSet {
        [
            // Split along function definitions
            "\nfunction ",
            // Split along class definitions
            "\nclass ",
            // Split along control flow statements
            "\nif ",
            "\nforeach ",
            "\nwhile ",
            "\ndo ",
            "\nswitch ",
            "\ncase ",
            // Split by the normal type of lines
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var javaScript: TextSplitterSeparatorSet {
        [
            // Split along function definitions
            "\nfunction ",
            "\nconst ",
            "\nlet ",
            "\nvar ",
            "\nclass ",
            // Split along control flow statements
            "\nif ",
            "\nfor ",
            "\nwhile ",
            "\nswitch ",
            "\ncase ",
            "\ndefault ",
            // Split by the normal type of lines
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var python: TextSplitterSeparatorSet {
        [
            // First, try to split along class definitions
            "\nclass ",
            "\ndef ",
            "\n\tdef ",
            // Now split by the normal type of lines
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var rust: TextSplitterSeparatorSet {
        [
            // Split along function definitions
            "\nfn ",
            "\nconst ",
            "\nlet ",
            // Split along control flow statements
            "\nif ",
            "\nwhile ",
            "\nfor ",
            "\nloop ",
            "\nmatch ",
            "\nconst ",
            // Split by the normal type of lines
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var ruby: TextSplitterSeparatorSet {
        [
            // Split along method definitions
            "\ndef ",
            "\nclass ",
            // Split along control flow statements
            "\nif ",
            "\nunless ",
            "\nwhile ",
            "\nfor ",
            "\ndo ",
            "\nbegin ",
            "\nrescue ",
            // Split by the normal type of lines
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var markdown: TextSplitterSeparatorSet {
        [
            // First, try to split along Markdown headings (starting with level 2)
            "\n## ",
            "\n### ",
            "\n#### ",
            "\n##### ",
            "\n###### ",
            // Note the alternative syntax for headings (below) is not handled here
            // Heading level 2
            // ---------------
            // End of code block
            "```\n\n",
            // Horizontal lines
            "\n\n***\n\n",
            "\n\n---\n\n",
            "\n\n___\n\n",
            // Note that this splitter doesn't handle horizontal lines defined
            // by *three or more* of ***, ---, or ___, but this is not handled
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            " ",
            "",
        ]
    }

    public static var latex: TextSplitterSeparatorSet {
        [
            // First, try to split along Latex sections
            "\n\\chapter{",
            "\n\\section{",
            "\n\\subsection{",
            "\n\\subsubsection{",
            // Now split by environments
            "\n\\begin{enumerate}",
            "\n\\begin{itemize}",
            "\n\\begin{description}",
            "\n\\begin{list}",
            "\n\\begin{quote}",
            "\n\\begin{quotation}",
            "\n\\begin{verse}",
            "\n\\begin{verbatim}",
            // Now split by math environments
            "\n\\begin{align}",
            "$$",
            "$",
            // Now split by the normal type of lines
            " ",
            "",
        ]
    }

    public static var html: TextSplitterSeparatorSet {
        [
            // First, try to split along HTML tags
            "<body>",
            "<div>",
            "<p>",
            "<br>",
            "<li>",
            "<h1>",
            "<h2>",
            "<h3>",
            "<h4>",
            "<h5>",
            "<h6>",
            "<span>",
            "<table>",
            "<tr>",
            "<td>",
            "<th>",
            "<ul>",
            "<ol>",
            "<header>",
            "<footer>",
            "<nav>",
            // Head
            "<head>",
            "<style>",
            "<script>",
            "<meta>",
            "<title>",
            "\n\n",
            "\r\n",
            "\n",
            "\r",
            "",
        ]
    }

    public static var `default`: TextSplitterSeparatorSet {
        ["\n\n", "\r\n", "\n", "\r", " ", ""]
    }
}


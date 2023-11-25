import SwiftTreeSitter
import SwiftUI

public extension ASTTree {
    /// Dumps the syntax tree as a string, for debugging purposes.
    func dump() -> AttributedString {
        guard let tree, let root = tree.rootNode else { return "" }
        var result: AttributedString = ""

        let appendNode: (_ level: Int, _ node: Node, _ name: String) -> Void = {
            level, node, name in
            let range = node.pointRange
            let lowerBoundL = range.lowerBound.row
            let lowerBoundC = range.lowerBound.column / 2
            let upperBoundL = range.upperBound.row
            let upperBoundC = range.upperBound.column / 2
            let indentation = AttributedString(String(repeating: "  ", count: level))
            let nodeInfo = {
                if name.isEmpty {
                    return AttributedString(node.nodeType ?? "N/A", attributes: .init([
                        .foregroundColor: NSColor.blue,
                    ]))
                } else {
                    var string = AttributedString("\(name): ", attributes: .init([
                        .foregroundColor: NSColor.brown,
                    ]))
                    string.append(AttributedString(node.nodeType ?? "N/A", attributes: .init([
                        .foregroundColor: NSColor.blue,
                    ])))
                    return string
                }
            }()
            let rangeText = "[\(lowerBoundL), \(lowerBoundC)] - [\(upperBoundL), \(upperBoundC)]"

            var line: AttributedString = ""
            line.append(indentation)
            line.append(nodeInfo)
            line.append(AttributedString(" \(rangeText)\n"))
            
            result.append(line)
        }

        func enumerate(_ node: Node, level: Int, name: String) {
            appendNode(level, node, name)
            for i in 0..<node.childCount {
                let n = node.child(at: i)!
                enumerate(n, level: level + 1, name: node.fieldNameForChild(at: i) ?? "")
            }
        }

        enumerate(root, level: 0, name: "root")
        return result
    }
}


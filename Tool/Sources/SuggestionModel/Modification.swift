import Foundation

public enum Modification: Codable, Equatable {
    case deleted(ClosedRange<Int>)
    case inserted(Int, [String])
}

public extension [String] {
    mutating func apply(_ modifications: [Modification]) {
        for modification in modifications {
            switch modification {
            case let .deleted(range):
                if isEmpty { break }
                let removingRange = range.lowerBound..<(range.upperBound + 1)
                removeSubrange(removingRange.clamped(to: 0..<endIndex))
            case let .inserted(index, strings):
                insert(contentsOf: strings, at: Swift.min(endIndex, index))
            }
        }
    }

    func applying(_ modifications: [Modification]) -> Array {
        var newArray = self
        newArray.apply(modifications)
        return newArray
    }
}

public extension NSMutableArray {
    func apply(_ modifications: [Modification]) {
        for modification in modifications {
            switch modification {
            case let .deleted(range):
                if count == 0 { break }
                let newRange = range.clamped(to: 0...(count - 1))
                removeObjects(in: NSRange(newRange))
            case let .inserted(index, strings):
                for string in strings.reversed() {
                    insert(string, at: Swift.min(count, index))
                }
            }
        }
    }
}

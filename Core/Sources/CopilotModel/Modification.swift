import Foundation

public enum Modification: Codable, Equatable {
    case deleted(ClosedRange<Int>)
    case inserted(Int, [String])
}

public extension Array where Element == String {
    mutating func apply(_ modifications: [Modification]) {
        for modification in modifications {
            switch modification {
            case let .deleted(range):
                if isEmpty { break }
                let removingRange = range.lowerBound ..< (range.upperBound + 1)
                removeSubrange(removingRange.clamped(to: 0 ..< endIndex))
            case let .inserted(index, strings):
                insert(contentsOf: strings, at: index)
            }
        }
    }

    func applying(_ modifications: [Modification]) -> Array {
        var newArray = self
        newArray.apply(modifications)
        return newArray
    }
}

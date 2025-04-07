import Foundation

public struct JoinJSON {
    public init() {}

    public func join(_ a: String, with b: String) -> Data {
        return join(a.data(using: .utf8) ?? Data(), with: b.data(using: .utf8) ?? Data())
    }

    public func join(_ a: Data, with b: String) -> Data {
        return join(a, with: b.data(using: .utf8) ?? Data())
    }

    public func join(_ a: Data, with b: Data) -> Data {
        guard let firstDict = try? JSONSerialization.jsonObject(with: a) as? [String: Any],
              let secondDict = try? JSONSerialization.jsonObject(with: b) as? [String: Any]
        else {
            return a
        }

        var merged = firstDict
        for (key, value) in secondDict {
            merged[key] = value
        }

        return (try? JSONSerialization.data(withJSONObject: merged)) ?? a
    }
}


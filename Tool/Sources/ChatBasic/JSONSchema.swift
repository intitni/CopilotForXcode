import Foundation

public struct JSONSchemaKey: Codable, Hashable, Sendable, Equatable, ExpressibleByStringLiteral {
    public var key: String
    
    public init(stringLiteral: String) {
        key = stringLiteral
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(key)
    }
    
    public init(from decoder: Decoder) throws {
        let single = try? decoder.singleValueContainer()
        if let value = try? single?.decode(String.self) {
            key = value
            return
        }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "failed to decode JSON schema key"))
    }
    
    public static let type: JSONSchemaKey = "type"
    public static let minLength: JSONSchemaKey = "minLength"
    public static let maxLength: JSONSchemaKey = "maxLength"
    public static let pattern: JSONSchemaKey = "pattern"
    public static let format: JSONSchemaKey = "format"
    public static let multipleOf: JSONSchemaKey = "multipleOf"
    public static let minimum: JSONSchemaKey = "minimum"
    public static let exclusiveMinimum: JSONSchemaKey = "exclusiveMinimum"
    public static let maximum: JSONSchemaKey = "maximum"
    public static let exclusiveMaximum: JSONSchemaKey = "exclusiveMaximum"
    public static let minProperties: JSONSchemaKey = "minProperties"
    public static let maxProperties: JSONSchemaKey = "maxProperties"
    public static let required: JSONSchemaKey = "required"
    public static let properties: JSONSchemaKey = "properties"
    public static let patternProperties: JSONSchemaKey = "patternProperties"
    public static let additionalProperties: JSONSchemaKey = "additionalProperties"
    public static let dependencies: JSONSchemaKey = "dependencies"
    public static let propertyNames: JSONSchemaKey = "propertyNames"
    public static let minItems: JSONSchemaKey = "minItems"
    public static let maxItems: JSONSchemaKey = "maxItems"
    public static let uniqueItems: JSONSchemaKey = "uniqueItems"
    public static let items: JSONSchemaKey = "items"
    public static let additionalItems: JSONSchemaKey = "additionalItems"
    public static let contains: JSONSchemaKey = "contains"
    public static let `enum`: JSONSchemaKey = "enum"
    public static let const: JSONSchemaKey = "const"
    public static let title: JSONSchemaKey = "title"
    public static let description: JSONSchemaKey = "description"
    public static let `default`: JSONSchemaKey = "default"
    public static let examples: JSONSchemaKey = "examples"
    public static let comment: JSONSchemaKey = "$comment"
    public static let allOf: JSONSchemaKey = "allOf"
    public static let anyOf: JSONSchemaKey = "anyOf"
    public static let oneOf: JSONSchemaKey = "oneOf"
    public static let not: JSONSchemaKey = "not"
    public static let `if`: JSONSchemaKey = "if"
    public static let then: JSONSchemaKey = "then"
    public static let `else`: JSONSchemaKey = "else"
}


public enum JSONSchemaValue: Codable, Hashable, Sendable {
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONSchemaValue])
    case hash([String: JSONSchemaValue])

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .hash(let value):
            try container.encode(value)
        }
    }

    public init(from decoder: Decoder) throws {
        let single = try? decoder.singleValueContainer()

        if let value = try? single?.decode([String: JSONSchemaValue].self) {
            self = .hash(value)
            return
        }

        if let value = try? single?.decode([JSONSchemaValue].self) {
            self = .array(value)
            return
        }

        if let value = try? single?.decode(String.self) {
            self = .string(value)
            return
        }

        if let value = try? single?.decode(Double.self) {
            self = .number(value)
            return
        }

        if let value = try? single?.decode(Bool.self) {
            self = .bool(value)
            return
        }

        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "failed to decode JSON schema object"))
    }
}

extension JSONSchemaValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (JSONSchemaKey, JSONSchemaValue)...) {
        var hash = [String: JSONSchemaValue]()

        for element in elements {
            hash[element.0.key] = element.1
        }

        self = .hash(hash)
    }
}

extension JSONSchemaValue: ExpressibleByStringLiteral {
    public init(stringLiteral: String) {
        self = .string(stringLiteral)
    }
}

extension JSONSchemaValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .number(Double(value))
    }
}

extension JSONSchemaValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .number(value)
    }
}

extension JSONSchemaValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONSchemaValue...) {
        var array = [JSONSchemaValue]()

        for element in elements {
            array.append(element)
        }

        self = .array(array)
    }
}

extension JSONSchemaValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
}

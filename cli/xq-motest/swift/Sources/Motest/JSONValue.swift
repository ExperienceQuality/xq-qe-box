import Foundation

public enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(any value: Any) {
        switch value {
        case is NSNull:
            self = .null
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .int(value)
        case let value as Double:
            self = .double(value)
        case let value as String:
            self = .string(value)
        case let value as [Any]:
            self = .array(value.map { JSONValue(any: $0) })
        case let value as [String: Any]:
            self = .object(value.mapValues { JSONValue(any: $0) })
        default:
            self = .null
        }
    }

    public var foundationValue: Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .string(let value):
            return value
        case .array(let values):
            return values.map(\.foundationValue)
        case .object(let values):
            return values.mapValues(\.foundationValue)
        }
    }

    public func data() throws -> Data {
        try JSONSerialization.data(withJSONObject: foundationValue, options: [])
    }

    public static func decode(from data: Data) throws -> JSONValue {
        let object = try JSONSerialization.jsonObject(with: data)
        return JSONValue(any: object)
    }

    public static func decode(from string: String) throws -> JSONValue {
        guard let data = string.data(using: .utf8) else {
            throw CLIError.internal("invalid UTF-8")
        }
        return try decode(from: data)
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var intValue: Int? {
        switch self {
        case .int(let value):
            return value
        case .double(let value):
            return Int(value)
        default:
            return nil
        }
    }
}

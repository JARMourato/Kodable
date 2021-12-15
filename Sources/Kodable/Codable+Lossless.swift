import Foundation

// MARK: - LosslessDecodable

public typealias LosslessDecodable = LosslessStringConvertible & Decodable

// MARK: Helper types to decode lossless values

struct LosslessValue<T: LosslessDecodable>: Decodable {
    var value: T

    init(from decoder: Decoder) throws {
        guard let rawValue = T.losslessDecode(from: decoder), let value = T("\(rawValue)") else {
            throw Corrupted()
        }

        self.value = value
    }
}

struct LosslessDecodableArray<Element: Decodable>: Decodable {
    private struct ElementWrapper: Decodable {
        var element: Element?

        init(from decoder: Decoder) throws {
            guard let stringConvertibleElement = Element.self as? LosslessStringConvertible.Type else {
                throw Corrupted()
            }
            guard let rawValue = Element.losslessDecode(from: decoder) else {
                element = nil
                return
            }
            let value = stringConvertibleElement.init("\(rawValue)") as? Element
            element = value
        }
    }

    var elements: [Element]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        elements = try container.decode([ElementWrapper].self).compactMap(\.element)
    }
}

private struct Corrupted: Error {}

// MARK: Helper type to decode lossy arrays

struct LossyDecodableArray<Element: Decodable>: Decodable {
    private struct ElementWrapper: Decodable {
        var element: Element?

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            element = try? container.decode(Element.self)
        }
    }

    var elements: [Element]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let wrappers = try container.decode([ElementWrapper].self)
        elements = wrappers.compactMap(\.element)
    }
}

extension Decodable where Self: LosslessStringConvertible {
    static func losslessDecode(from container: DecodeContainer, with key: String) throws -> Self {
        func decode<T: Decodable>(_ type: T.Type) -> T? {
            try? container.decode(type, with: key)
        }

        guard let decoded = decode(Self.self) ?? decode(LosslessValue<Self>.self)?.value else {
            if container.containsValue(for: key) { throw KodableError.invalidValueForPropertyWithKey(key) }
            throw KodableError.nonOptionalValueMissing(property: key)
        }
        return decoded
    }

    static func losslessDecodeIfPresent(from container: DecodeContainer, with key: String) throws -> Self? {
        func decode<T: Decodable>(_ type: T.Type) throws -> T? {
            try container.decodeIfPresent(type, with: key)
        }

        let value = try? decode(Self.self)

        return try value ?? decode(LosslessValue<Self>.self)?.value
    }
}

private extension Decodable {
    static func losslessDecode(from decoder: Decoder) -> LosslessDecodable? {
        func decode<T: LosslessDecodable>(_: T.Type) -> (Decoder) -> LosslessDecodable? {
            { try? T(from: $0) }
        }

        // The order of the types matter!!
        let types: [(Decoder) -> LosslessDecodable?] = [
            decode(String.self),
            decodeBoolFromNSNumber(),
            decode(Bool.self),
            decode(Int.self),
            decode(Int8.self),
            decode(Int16.self),
            decode(Int64.self),
            decode(UInt.self),
            decode(UInt8.self),
            decode(UInt16.self),
            decode(UInt64.self),
            decode(Double.self),
            decode(Float.self),
        ]

        return types.lazy.compactMap { $0(decoder) }.first
    }

    private static func decodeBoolFromNSNumber() -> (Decoder) -> LosslessDecodable? {
        guard self is Bool.Type else {
            return { _ in nil }
        }
        return { (try? Int(from: $0)).flatMap { Bool(exactly: NSNumber(value: $0)) } }
    }
}

// MARK: Sequence + Lossless & Lossy

protocol DecodableSequence {
    static func decodeSequence(from container: DecodeContainer, with key: String, decoding: PropertyDecoding) throws -> Self
    static func decodeSequenceIfPresent(from container: DecodeContainer, with key: String, decoding: PropertyDecoding) throws -> Self?
    static func sequenceDecoding(from container: DecodeContainer, with key: String, decoding: PropertyDecoding) throws -> Self
}

extension DecodableSequence {
    static func decodeSequence(from container: DecodeContainer, with key: String, decoding: PropertyDecoding) throws -> Self {
        guard let decoded = try? sequenceDecoding(from: container, with: key, decoding: decoding) else {
            if container.containsValue(for: key) { throw KodableError.invalidValueForPropertyWithKey(key) }
            throw KodableError.nonOptionalValueMissing(property: key)
        }
        return decoded
    }

    static func decodeSequenceIfPresent(from container: DecodeContainer, with key: String, decoding: PropertyDecoding) throws -> Self? {
        try? sequenceDecoding(from: container, with: key, decoding: decoding)
    }
}

private struct AnyValue: Decodable {}

extension Array: DecodableSequence where Element: Decodable {
    static func sequenceDecoding(from container: DecodeContainer, with key: String, decoding: PropertyDecoding) throws -> [Element] {
        switch decoding {
        case .enforceType: return try container.decode([Element].self, with: key)
        case .lossy: return try container.decode(LossyDecodableArray<Element>.self, with: key).elements
        case .lossless: return try container.decode(LosslessDecodableArray<Element>.self, with: key).elements
        }
    }
}

// MARK: Optional LossLessDecodable Conformance

extension Optional: CustomStringConvertible where Wrapped: LosslessDecodable {
    public var description: String {
        switch self {
        case let .some(value): return value.description
        case .none: return "Empty Optional<\(String(describing: Wrapped.self))>"
        }
    }
}

extension Optional: LosslessStringConvertible where Wrapped: LosslessDecodable {
    public init?(_ description: String) {
        self = Wrapped(description)
    }
}

extension Optional: DecodableSequence where Wrapped: DecodableSequence {
    static func sequenceDecoding(from container: DecodeContainer, with key: String, decoding: PropertyDecoding) throws -> Wrapped? {
        try Wrapped.decodeSequenceIfPresent(from: container, with: key, decoding: decoding)
    }
}

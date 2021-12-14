import Foundation

// MARK: - LosslessDecodable

public typealias LosslessDecodable = LosslessStringConvertible & Decodable

// MARK: Helper type to decode lossless values

struct LosslessValue<T: Decodable>: Decodable {
    var value: T

    // Nested Types
    struct Corrupted: Error {}

    init(from decoder: Decoder) throws {
        func decode<T: LosslessDecodable>(_: T.Type) -> (Decoder) -> LosslessDecodable? {
            { try? T(from: $0) }
        }

        func decodeBoolFromNSNumber() -> (Decoder) -> LosslessDecodable? {
            { (try? Int(from: $0)).flatMap { Bool(exactly: NSNumber(value: $0)) } }
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

        guard let anyLosslessDecodable = T.self as? LosslessDecodable.Type, let rawValue = types.lazy.compactMap({ $0(decoder) }).first, let value = anyLosslessDecodable.init("\(rawValue)") as? T else {
            throw Corrupted()
        }

        self.value = value
    }
}

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
        case .lossless:
            let decoder = try container.superDecoder(forKey: key)
            var container = try decoder.unkeyedContainer()

            var elements: [Element] = []
            while !container.isAtEnd {
                do {
                    guard let value = try container.decodeIfPresent(LosslessValue<Element>.self)?.value else { continue }
                    elements.append(value)
                } catch {
                    _ = try? container.decode(AnyValue.self)
                }
            }

            return elements
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

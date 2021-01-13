import Foundation

// MARK: - CodableModifier

// MARK: Property Decoding

public enum PropertyDecoding {
    /// Enforces the property type when decoding. If the value present in the decoder does not match, decoding will fail. This is the default option.
    case enforceType
    /// Tries decoding the property type from other compatible types, adding resilence to the decoding process. This uses `LosslessStringConvertible` under the hood.
    case lossless
    /// This option is only relevant to `Collection` types. It allows to decode elements, ignoring individual elements for which decoding failed.
    /// if selected for non compatible types, `enforceType` will be used
    case lossy
}

// MARK: Modifier Holder Type

/// A holder type for changes that can be made when decoding a `Decodable` value
public enum KodableModifier<T> {
    /// Entrypoint to override the decoded value.
    case custom(OverrideValueClosure)
    /// Changes the decoding method used. Defaults to `decoding(.enforceType)`.
    case decoding(PropertyDecoding)
    /// Adds a validation step at the end before assigning the value that was decoded.
    case validation(ValidationClosure)

    // MARK: Nested types

    public typealias ValidationClosure = (T) -> Bool
    public typealias OverrideValueClosure = (T) -> T

    internal func validate(_ value: T) -> Bool {
        guard case let .validation(validationClosure) = self else { return true }
        return validationClosure(value)
    }

    internal func overrideValue(_ value: T) -> T {
        guard case let .custom(overrideClosure) = self else { return value }
        return overrideClosure(value)
    }

    internal var decodingKind: PropertyDecoding? {
        guard case let .decoding(value) = self else { return nil }
        return value
    }
}

// MARK: Built in preset modifiers

// Syntatic sugar
public extension KodableModifier {
    /// Applies lossless decoding. Tries to decode properties from other compatible types than itself. This uses `LosslessStringConvertible` under the hood.
    static var lossless: KodableModifier { .decoding(.lossless) }

    /// Applies lossy decoding. Only applicable to `Collection` types. In all other cases it will default to `enforceType`
    static var lossy: KodableModifier { .decoding(.lossy) }
}

public extension KodableModifier where T == String {
    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded. Only applicable to String and Optional<String>
    static var trimmed: KodableModifier { KodableModifier.custom { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
}

public extension KodableModifier where T == String? {
    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded. Only applicable to String and Optional<String>
    static var trimmed: KodableModifier { KodableModifier.custom { $0?.trimmingCharacters(in: .whitespacesAndNewlines) } }

    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded, returns nif if empty. Only applicable to Optional<String>
    static var trimmedNifIfEmpty: KodableModifier {
        KodableModifier.custom {
            let result = $0?.trimmingCharacters(in: .whitespacesAndNewlines)
            return result?.isEmpty == true ? nil : result
        }
    }
}

public extension KodableModifier where T: Comparable {
    /// Clamps the value in a range. Only applicable to types conforming to Comparable
    static func clamping(to range: ClosedRange<T>) -> KodableModifier { KodableModifier.custom { $0.constrained(to: range) } }

    /// Constrains the value inside a `range`. Only applicable to types conforming to Comparable
    static func range(_ range: ClosedRange<T>) -> KodableModifier { KodableModifier.custom { $0.constrained(to: range) } }

    /// Constrains the value to a `max` value. Only applicable to types conforming to Comparable
    static func max(_ value: T) -> KodableModifier { KodableModifier.custom { $0.constrained(toAtMost: value) } }

    /// Constrains the value to a `min` value. Only applicable to types conforming to Comparable
    static func min(_ value: T) -> KodableModifier { KodableModifier.custom { $0.constrained(toAtLeast: value) } }
}

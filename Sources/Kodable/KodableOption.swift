import Foundation

/// Represents the customizations that can be added to the decoding/encoding process.
public enum KodableOption<Value> {
    case debugJSON
    case encodeAsNullIfNil
    case modifier(KodableModifier<Value>)
    case propertyDecoding(PropertyDecoding)
}

// MARK: - Helper Types

// MARK: Decoding Strategy

public enum PropertyDecoding {
    case enforceType
    case lossless
    case lossy
}

// MARK: Modifying decoded value

public struct KodableModifier<T> {
    private let overrideValue: OverrideValueClosure
    private let validation: ValidationClosure

    public typealias ValidationClosure = (T) -> Bool
    public typealias OverrideValueClosure = (T) -> T

    // MARK: Initializers

    /// - Parameter validation: Adds a validation step at the end before assigning the value that was decoded.
    public init(_ validation: @escaping ValidationClosure) {
        overrideValue = { $0 }
        self.validation = validation
    }

    /// - Parameter overrideValue: Entrypoint to override the decoded value.
    public init(_ overrideValue: @escaping OverrideValueClosure) {
        self.overrideValue = overrideValue
        validation = { _ in true }
    }

    func validate(_ value: T) -> Bool { validation(value) }
    func overrideValue(_ value: T) -> T { overrideValue(value) }
}

// MARK: - Helpers

extension KodableOption {
    var modifier: KodableModifier<Value>? {
        guard case let .modifier(value) = self else { return nil }
        return value
    }

    var propertyDecoding: PropertyDecoding? {
        guard case let .propertyDecoding(value) = self else { return nil }
        return value
    }
}

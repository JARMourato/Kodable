import Foundation

// MARK: - CodableModifier

// MARK: Modifier Holder Type

public struct KodableModifier<T> {
    private let overrideValue: OverrideValueClosure
    private let validation: ValidationClosure

    // MARK: Nested types

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

    internal func validate(_ value: T) -> Bool { validation(value) }
    internal func overrideValue(_ value: T) -> T { overrideValue(value) }
}

// MARK: Built in preset modifiers

// Syntatic Sugar
public extension KodableModifier {
    static func validation(_ validation: @escaping ValidationClosure) -> KodableModifier { Self(validation) }
    static func overrideValue(_ overrideValue: @escaping OverrideValueClosure) -> KodableModifier { Self(overrideValue) }
}

public extension KodableModifier where T == String {
    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded. Only applicable to String and Optional<String>
    static var trimmed: KodableModifier { KodableModifier { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
}

public extension KodableModifier where T == String? {
    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded. Only applicable to String and Optional<String>
    static var trimmed: KodableModifier { KodableModifier { $0?.trimmingCharacters(in: .whitespacesAndNewlines) } }

    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded, returns nif if empty. Only applicable to Optional<String>
    static var trimmedNifIfEmpty: KodableModifier {
        KodableModifier { (value: String?) -> String? in
            let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return result?.isEmpty == true ? nil : result
        }
    }
}

public extension KodableModifier where T: Comparable {
    /// Clamps the value in a range. Only applicable to types conforming to Comparable
    static func clamping(to range: ClosedRange<T>) -> KodableModifier { KodableModifier { $0.constrained(to: range) } }

    /// Constrains the value inside a `range`. Only applicable to types conforming to Comparable
    static func range(_ range: ClosedRange<T>) -> KodableModifier { KodableModifier { $0.constrained(to: range) } }

    /// Constrains the value to a `max` value. Only applicable to types conforming to Comparable
    static func max(_ value: T) -> KodableModifier { KodableModifier { $0.constrained(toAtMost: value) } }

    /// Constrains the value to a `min` value. Only applicable to types conforming to Comparable
    static func min(_ value: T) -> KodableModifier { KodableModifier { $0.constrained(toAtLeast: value) } }
}

import Foundation

// MARK: - Property Decoding

extension KodableOption {
    /// Enforces the property type when decoding. If the value present in the decoder does not match, decoding will fail. This is the default option.
    static var enforceType: KodableOption { .propertyDecoding(.enforceType) }
    /// Tries decoding the property type from other compatible types, adding resilence to the decoding process. This uses `LosslessStringConvertible` under the hood.
    static var lossless: KodableOption { .propertyDecoding(.lossless) }
    /// This option is only relevant to `Collection` types. It allows to decode elements, ignoring individual elements for which decoding failed.
    /// if selected for non compatible types, `enforceType` will be used
    static var lossy: KodableOption { .propertyDecoding(.lossy) }
}

// MARK: - Value Decoded

// MARK: Syntatic Sugar

public extension KodableOption {
    static func overrideValue(_ overrideValue: @escaping KodableModifier<Value>.OverrideValueClosure) -> KodableOption { .modifier(KodableModifier(overrideValue)) }
    static func validation(_ validation: @escaping KodableModifier<Value>.ValidationClosure) -> KodableOption { .modifier(KodableModifier(validation)) }
}

// MARK: String Presets

public extension KodableOption where Value == String {
    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded. Only applicable to String and Optional<String>
    static var trimmed: KodableOption { .modifier(KodableModifier { $0.trimmingCharacters(in: .whitespacesAndNewlines) }) }
}

public extension KodableOption where Value == String? {
    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded. Only applicable to String and Optional<String>
    static var trimmed: KodableOption { .modifier(KodableModifier { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }) }

    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded, returns nif if empty. Only applicable to Optional<String>
    static var trimmedNifIfEmpty: KodableOption {
        .modifier(KodableModifier { (value: String?) -> String? in
            let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return result?.isEmpty == true ? nil : result
        })
    }
}

// MARK: Comparable Presets

public extension KodableOption where Value: Comparable {
    /// Clamps the value in a range. Only applicable to types conforming to Comparable
    static func clamping(to range: ClosedRange<Value>) -> KodableOption { .modifier(KodableModifier { $0.constrained(to: range) }) }

    /// Constrains the value inside a `range`. Only applicable to types conforming to Comparable
    static func range(_ range: ClosedRange<Value>) -> KodableOption { .modifier(KodableModifier { $0.constrained(to: range) }) }

    /// Constrains the value to a `max` value. Only applicable to types conforming to Comparable
    static func max(_ value: Value) -> KodableOption { .modifier(KodableModifier { $0.constrained(toAtMost: value) }) }

    /// Constrains the value to a `min` value. Only applicable to types conforming to Comparable
    static func min(_ value: Value) -> KodableOption { .modifier(KodableModifier { $0.constrained(toAtLeast: value) }) }
}

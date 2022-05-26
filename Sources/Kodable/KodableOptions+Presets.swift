import Foundation

// MARK: - Property Decoding

public extension KodableOption {
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
    static var trimmed: KodableOption { overrideValue { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
}

public extension KodableOption where Value == String? {
    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded. Only applicable to String and Optional<String>
    static var trimmed: KodableOption { overrideValue { $0?.trimmingCharacters(in: .whitespacesAndNewlines) } }

    /// Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded, returns nif if empty. Only applicable to Optional<String>
    static var trimmedNifIfEmpty: KodableOption {
        overrideValue { (value: String?) -> String? in
            let result = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return result?.isEmpty == true ? nil : result
        }
    }
}

// MARK: Sort Presets

public extension KodableOption where Value: Collection {
    typealias Comparator = (Value.Element, Value.Element) -> Bool

    /// Sorts the array using a `Comparator` closure that determines whether the items are in increasing order
    static func sorted(using comparator: @escaping Comparator) -> KodableOption {
        overrideValue { $0.sorted(by: comparator) as! Value }
    }

    /// Sorts the elements of an array ascending by a given keyPath
    static func ascending<C: Comparable>(by keyPath: KeyPath<Value.Element, C>) -> KodableOption {
        sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
    }

    /// Sorts the elements of an array descending by a given keyPath
    static func descending<C: Comparable>(by keyPath: KeyPath<Value.Element, C>) -> KodableOption {
        sorted { $0[keyPath: keyPath] > $1[keyPath: keyPath] }
    }
}

// MARK: Comparable Presets

public extension KodableOption where Value: Comparable {
    /// Clamps the value in a range. Only applicable to types conforming to Comparable
    static func clamping(to range: ClosedRange<Value>) -> KodableOption { overrideValue { $0.constrained(to: range) } }

    /// Constrains the value inside a `range`. Only applicable to types conforming to Comparable
    static func range(_ range: ClosedRange<Value>) -> KodableOption { overrideValue { $0.constrained(to: range) } }

    /// Constrains the value to a `max` value. Only applicable to types conforming to Comparable
    static func max(_ value: Value) -> KodableOption { overrideValue { $0.constrained(toAtMost: value) } }

    /// Constrains the value to a `min` value. Only applicable to types conforming to Comparable
    static func min(_ value: Value) -> KodableOption { overrideValue { $0.constrained(toAtLeast: value) } }
}

// MARK: Collection Presets

public extension KodableOption where Value: Collection, Value.Element: Comparable {
    /// Sorts the elements of an array ascending
    static var ascending: KodableOption { sorted { $0 < $1 } }
    /// Sorts the elements of an array descending
    static var descending: KodableOption { sorted { $0 > $1 } }
}

extension Optional: Comparable where Wrapped: Comparable {
    public static func < (lhs: Optional, rhs: Optional) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil), (_, nil): return true
        case (nil, _): return false
        default:
            guard let lhs = lhs, let rhs = rhs else { return false }
            return lhs < rhs
        }
    }
}

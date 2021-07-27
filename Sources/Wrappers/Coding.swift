import Foundation

// MARK: - Code Property Wrapper

/// A wrapper that helps modifying the decoding/encoding behavior.  The types that use this helper need to
/// conform to `Kodable`  to be able to be correctly decoded/encoded.
@propertyWrapper public final class Coding<T: Codable>: KodableTransformable<Passthrough<T>> {
    override public var wrappedValue: T {
        get { super.wrappedValue }
        set { super.wrappedValue = newValue }
    }

    /// - Parameters:
    ///   - decoding: Changes the decoding method used. Defaults to `decoding(.enforceType)`.
    public convenience init(decoding: PropertyDecoding = .enforceType, encodeAsNullIfNil: Bool = false, _ modifiers: KodableModifier<TargetType>..., default value: TargetType? = nil) {
        self.init(key: nil, decoding: decoding, encodeAsNullIfNil: encodeAsNullIfNil, modifiers: modifiers, defaultValue: value)
    }

    /// - Parameters:
    ///   - key: Customize the string key used to decode the value. Nested values are supported through the usage of the `.` notation.
    ///   - decoding: Changes the decoding method used. Defaults to `decoding(.enforceType)`.
    public convenience init(_ key: String, decoding: PropertyDecoding = .enforceType, encodeAsNullIfNil: Bool = false, _ modifiers: KodableModifier<TargetType>..., default value: TargetType? = nil) {
        self.init(key: key, decoding: decoding, encodeAsNullIfNil: encodeAsNullIfNil, modifiers: modifiers, defaultValue: value)
    }
}

// MARK: Passthrough transformer

/// The `Coding` wrapper is just a simpler version of the `KodableTransformable`. Therefore,
/// this type exists so that `Coding` can inherit all the behavior from `KodableTransformable`.
public struct Passthrough<T: Codable>: KodableTransform {
    public func transformFromJSON(value: T) -> T { value }
    public func transformToJSON(value: T) -> T { value }
    public init() {}
}

// MARK: Equatable Conformance

extension Coding: Equatable where T: Equatable {
    public static func == (lhs: Coding<T>, rhs: Coding<T>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

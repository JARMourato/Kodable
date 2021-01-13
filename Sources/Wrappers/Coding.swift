import Foundation

// MARK: - Code Property Wrapper

/// A wrapper that helps modifying the decoding/encoding behavior.  The types that use this helper need to
/// conform to `Kodable`  to be able to be correctly decoded/encoded.
@propertyWrapper public final class Coding<T: Codable>: KodableTransformable<Passthrough<T>> {
    override public var wrappedValue: T {
        get { super.wrappedValue }
        set { super.wrappedValue = newValue }
    }
    
    public convenience init(_ modifiers: KodableModifier<TargetType>..., default value: TargetType? = nil) {
        self.init(key: nil, modifiers: modifiers, defaultValue: value)
    }
    
    /// - Parameters:
    ///   - key: Customize the string key used to decode the value. Nested values are supported through the usage of the `.` notation.
    public convenience init(_ key: String, _ modifiers: KodableModifier<TargetType>..., default value: TargetType? = nil) {
        self.init(key: key, modifiers: modifiers, defaultValue: value)
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

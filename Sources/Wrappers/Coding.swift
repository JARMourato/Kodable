import Foundation

// MARK: - Code Property Wrapper

/// A wrapper that helps modifying the decoding/encoding behavior.  The types that use this helper need to
/// conform to `Kodable`  to be able to be correctly decoded/encoded.
@propertyWrapper public final class Coding<T: Codable>: KodableTransformable<Passthrough<T>> {
    override public var wrappedValue: T {
        get { super.wrappedValue }
        set { super.wrappedValue = newValue }
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

import Foundation

// MARK: - Code Property Wrapper

/// A wrapper that helps modifying the decoding/encoding behavior.  The types that use this helper need to
/// conform to `Kodable`  to be able to be correctly decoded/encoded.
@propertyWrapper public struct Coding<T: Codable>: Codable {
    private var inner: KodableTransformable<Passthrough<T>>

    public var wrappedValue: T {
        get { inner.wrappedValue }
        set { inner.wrappedValue = newValue }
    }

    public init() {
        self.inner = KodableTransformable()
    }

    public init(_ options: KodableOption<T>..., default value: T? = nil) {
        self.inner = KodableTransformable(options: options, defaultValue: value)
    }

    public init(_ key: String, _ options: KodableOption<T>..., default value: T? = nil) {
        self.inner = KodableTransformable(key: key, options: options, defaultValue: value)
    }

    public init(from decoder: Decoder) throws {
        self.inner = try KodableTransformable(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try inner.encode(to: encoder)
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

// MARK: - Decoding Property

extension Coding: DecodableProperty where T: Decodable {
    mutating func decodeValueForProperty(with propertyName: String, from container: DecodeContainer) throws {
        try inner.decodeValueForProperty(with: propertyName, from: container)
    }
}

// MARK: - Encoding Property

extension Coding: EncodableProperty where T: Encodable {
    func encodeValueFromProperty(with propertyName: String, to container: inout EncodeContainer) throws {
        try inner.encodeValueFromProperty(with: propertyName, to: &container)
    }
}

// MARK: Equatable Conformance

extension Coding: Equatable where T: Equatable {
    public static func == (lhs: Coding<T>, rhs: Coding<T>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

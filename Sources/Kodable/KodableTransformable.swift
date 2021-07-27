import Foundation

// MARK: - Kodable Transformable

// MARK: Kodable Transformable Protocol

public protocol KodableTransform {
    associatedtype From: Codable
    associatedtype To
    func transformFromJSON(value: From) throws -> To
    func transformToJSON(value: To) throws -> From
    init()
}

// MARK: Kodable Transformable Property Wrapper

@propertyWrapper open class KodableTransformable<T: KodableTransform>: Codable {
    internal var transformer = T()
    internal var _value: T.To?
    private let modifiers: [KodableModifier<TargetType>]
    public private(set) var key: String?
    public private(set) var decoding: PropertyDecoding = .enforceType

    public typealias OriginalType = T.From
    public typealias TargetType = T.To

    private func _wrappedValue<U>(_: U.Type) -> U {
        guard _value != nil || U.self is OptionalProtocol.Type else {
            fatalError("Trying to access a non optional property that has not been decoded - the property value is nil internally")
        }
        return _value as! U
    }

    /// - Note: this might crash if an instance of a type uses the property wrapper with a non-optional type
    ///         and it can't be decoded, and a default value wasn't provided.
    public var wrappedValue: TargetType {
        get { _wrappedValue(TargetType.self) } // This is needed so that we can return TargetType as the correct type
        set { _value = newValue }
    }

    internal init(key: String? = nil, decoding: PropertyDecoding, modifiers: [KodableModifier<TargetType>], defaultValue: TargetType?) {
        self.key = key
        self.modifiers = modifiers
        self.decoding = decoding
        _value = defaultValue
    }

    // MARK: Public Initializers

    public init() {
        modifiers = []
    }

    // MARK: Codable Conformance

    /// All custom behavior is lost when the `Decodable` initializer is used
    public required init(from decoder: Decoder) throws {
        let decodedValue = try T.From(from: decoder)
        _value = try transformer.transformFromJSON(value: decodedValue)
        modifiers = []
    }

    public func encode(to encoder: Encoder) throws {
        guard let value = _value else { return }
        let encodableValue = try transformer.transformToJSON(value: value)
        try encodableValue.encode(to: encoder)
    }
}

// MARK: Modifier Handling

extension KodableTransformable {
    private func overrideValueDecoded(_ value: TargetType) -> TargetType {
        var modifiedCopy = value
        for modifier in modifiers { modifiedCopy = modifier.overrideValue(modifiedCopy) }
        return modifiedCopy
    }

    private func validate(_ value: TargetType) -> Bool {
        modifiers.first { $0.validate(value) == false } == nil
    }
}

// MARK: - Decoding Property

extension KodableTransformable: DecodableProperty where OriginalType: Decodable {
    // MARK: Main ExtendedTransformable decoding logic

    func decodeValueForProperty(with propertyName: String, from container: DecodeContainer) throws {
        let fromValue: OriginalType
        let originalTypeIsOptional = try Reflection.typeInformation(of: OriginalType.self).kind == .optional
        let targetTypeIsOptional = try Reflection.typeInformation(of: TargetType.self).kind == .optional

        // When the property type is optional, parsing may fail
        if originalTypeIsOptional, targetTypeIsOptional {
            guard let decoded = try? decodeSourceValue(with: propertyName, from: container, typeIsOptional: originalTypeIsOptional) else { return }
            fromValue = decoded
        } else {
            do {
                fromValue = try decodeSourceValue(with: propertyName, from: container, typeIsOptional: originalTypeIsOptional)
            } catch {
                // When the property type is non optional, if there is a default value
                // then proceed decoding, otherwise fail.
                guard _value == nil else { return }
                throw error
            }
        }

        let convertedValue = try transformer.transformFromJSON(value: fromValue) // 1: Apply transformation
        let finalValue = overrideValueDecoded(convertedValue) // 2: Go through all value modifiers and override the decoded value
        let valueIsValid = validate(finalValue) // 3: Go through the validators and check that none fails

        guard valueIsValid else { throw KodableError.validationFailed(property: propertyName, parsedValue: finalValue) }

        wrappedValue = finalValue
    }

    private func decodeSourceValue(with propertyName: String, from container: DecodeContainer, typeIsOptional: Bool) throws -> OriginalType {
        var copyContainer = container

        let stringKeyPath = key ?? propertyName
        let (relevantContainer, relevantKey) = try copyContainer.nestedContainerAndKey(for: stringKeyPath)

        let valueDecoded: OriginalType?

        if let anyDecodable = OriginalType.self as? DecodableSequence.Type {
            if typeIsOptional {
                valueDecoded = try anyDecodable.decodeSequenceIfPresent(from: relevantContainer, with: relevantKey, decoding: decoding) as? OriginalType
            } else {
                valueDecoded = try anyDecodable.decodeSequence(from: relevantContainer, with: relevantKey, decoding: decoding) as? OriginalType
            }
        } else if decoding == .lossless, let anyDecodable = OriginalType.self as? LosslessDecodable.Type {
            if typeIsOptional {
                valueDecoded = try anyDecodable.losslessDecodeIfPresent(from: relevantContainer, with: relevantKey) as? OriginalType
            } else {
                valueDecoded = try anyDecodable.losslessDecode(from: relevantContainer, with: relevantKey) as? OriginalType
            }
        } else {
            do {
                valueDecoded = try relevantContainer.decodeIfPresent(OriginalType.self, forKey: AnyCodingKey(relevantKey))
            } catch {
                guard case DecodingError.typeMismatch = error else { throw error }
                throw KodableError.invalidValueForPropertyWithKey(relevantKey)
            }
        }

        // Note: Find an elegant way to remove the double optional, for now this will do
        let flattened = valueDecoded.flattened()

        guard let value = flattened else {
            throw KodableError.nonOptionalValueMissing(property: stringKeyPath)
        }

        return value as! OriginalType
    }
}

// MARK: - Encoding Property

extension KodableTransformable: EncodableProperty where OriginalType: Encodable {
    // MARK: Main ExtendedTransformable encoding logic

    func encodeValueFromProperty(with propertyName: String, to container: inout EncodeContainer) throws {
        var (relevantContainer, relavantKey) = try container.nestedContainerAndKey(for: key ?? propertyName)
        let encodableValue = try transformer.transformToJSON(value: wrappedValue)
        try relevantContainer.encode(encodableValue, with: relavantKey)
    }
}

// MARK: - Property Decoding

public enum PropertyDecoding {
    /// Enforces the property type when decoding. If the value present in the decoder does not match, decoding will fail. This is the default option.
    case enforceType
    /// Tries decoding the property type from other compatible types, adding resilence to the decoding process. This uses `LosslessStringConvertible` under the hood.
    case lossless
    /// This option is only relevant to `Collection` types. It allows to decode elements, ignoring individual elements for which decoding failed.
    /// if selected for non compatible types, `enforceType` will be used
    case lossy
}

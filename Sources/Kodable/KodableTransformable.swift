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

@propertyWrapper public struct KodableTransformable<T: KodableTransform>: Codable {
    var transformer = T()
    var _value: T.To?
    private let options: [KodableOption<TargetType>]
    public private(set) var key: String?

    public typealias OriginalType = T.From
    public typealias TargetType = T.To

    private func getValue<U>(_: U.Type) -> U {
        guard _value != nil || U.self is OptionalProtocol.Type else {
            fatalError("Trying to access a non optional property that has not been decoded - the property value is nil internally")
        }
        return _value as! U
    }

    private mutating func setValue(_ newValue: TargetType, for propertyName: String = "") throws {
        let finalValue = overrideRawValueIfNeeded(newValue) // 1: Go through all value modifiers and override it if needed
        let valueIsValid = validate(finalValue) // 2: Go through the validators and check that none fails

        guard valueIsValid else {
            throw KodableError.validationFailed(type: TargetType.self, property: propertyName, parsedValue: finalValue)
        }

        _value = finalValue
    }

    /// - Note: this might crash if an instance of a type uses the property wrapper with a non-optional type
    ///         and it can't be decoded, and a default value wasn't provided.
    public var wrappedValue: TargetType {
        get {
            getValue(TargetType.self)
        }
        mutating set {
            try? setValue(newValue)
        }
    }

    // MARK: Public Initializers

    public init(wrappedValue: TargetType) {
        key = nil
        options = []
        _value = wrappedValue
    }

    public init() {
        options = []
    }

    public init(key: String? = nil, options: [KodableOption<TargetType>] = [], defaultValue: TargetType? = nil) {
        self.key = key
        self.options = options
        _value = defaultValue
    }

    // MARK: Codable Conformance

    /// All custom behavior is lost when the `Decodable` initializer is used
    public init(from decoder: Decoder) throws {
        let decodedValue = try T.From(from: decoder)
        _value = try transformer.transformFromJSON(value: decodedValue)
        options = []
    }

    public func encode(to encoder: Encoder) throws {
        guard let value = _value else { return }
        let encodableValue = try transformer.transformToJSON(value: value)
        try encodableValue.encode(to: encoder)
    }
}

// MARK: Modifier Handling

extension KodableTransformable {
    private func overrideRawValueIfNeeded(_ value: TargetType) -> TargetType {
        var modifiedCopy = value
        for modifier in modifiers {
            modifiedCopy = modifier.overrideValue(modifiedCopy)
        }
        return modifiedCopy
    }

    private func validate(_ value: TargetType) -> Bool {
        modifiers.first { $0.validate(value) == false } == nil
    }
}

// MARK: - Decoding Property

extension KodableTransformable: DecodableProperty where OriginalType: Decodable {
    // MARK: Main ExtendedTransformable decoding logic

    mutating func decodeValueForProperty(with propertyName: String, from container: DecodeContainer) throws {
        let fromValue: OriginalType
        let originalTypeIsOptional = try Reflection.typeInformation(of: OriginalType.self).kind == .optional
        let targetTypeIsOptional = try Reflection.typeInformation(of: TargetType.self).kind == .optional

        if debugJSON {
            debugJSONProperty(from: container, for: propertyName, with: TargetType.self)
        }

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
        try setValue(convertedValue, for: propertyName) // 2: try setting the converted value
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
                valueDecoded = try anyDecodable.decodeSequence(from: relevantContainer, for: propertyName, with: relevantKey, decoding: decoding) as? OriginalType
            }
        } else if decoding == .lossless, let anyDecodable = OriginalType.self as? LosslessDecodable.Type {
            if typeIsOptional {
                valueDecoded = try anyDecodable.losslessDecodeIfPresent(from: relevantContainer, with: relevantKey) as? OriginalType
            } else {
                valueDecoded = try anyDecodable.losslessDecode(from: relevantContainer, for: propertyName, with: relevantKey) as? OriginalType
            }
        } else {
            do {
                valueDecoded = try relevantContainer.decodeIfPresent(OriginalType.self, forKey: AnyCodingKey(relevantKey))
            } catch {
                throw KodableError.failedDecodingProperty(property: propertyName, key: relevantKey, type: TargetType.self, underlyingError: .create(from: error))
            }
        }

        // Note: Find an elegant way to remove the double optional, for now this will do
        let flattened = valueDecoded.flattened()

        guard let value = flattened else {
            throw KodableError.failedDecodingProperty(property: propertyName, key: stringKeyPath, type: TargetType.self, underlyingError: .dataNotFound)
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
        let isValueNil = (encodableValue as? OptionalProtocol)?.isNil ?? false
        guard !isValueNil || encodeAsNullIfNil else { return }
        try relevantContainer.encode(encodableValue, with: relavantKey)
    }
}

// MARK: - Options

extension KodableTransformable {
    public var decoding: PropertyDecoding {
        options.compactMap(\.propertyDecoding).last ?? .enforceType
    }

    private var debugJSON: Bool {
        options.contains { option in
            guard case .debugJSON = option else { return false }
            return true
        }
    }

    public var encodeAsNullIfNil: Bool {
        options.contains { option in
            guard case .encodeAsNullIfNil = option else { return false }
            return true
        }
    }

    private var modifiers: [KodableModifier<TargetType>] {
        options.compactMap(\.modifier)
    }
}

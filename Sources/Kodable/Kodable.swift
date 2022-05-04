import Foundation

// MARK: - Extended Codable Protocols

// MARK: Extended Codable properties

protocol DecodableProperty {
    func decodeValueForProperty(with propertyName: String, from container: DecodeContainer) throws
}

protocol EncodableProperty {
    func encodeValueFromProperty(with propertyName: String, to container: inout EncodeContainer) throws
}

// MARK: Extended Decodable protocol

/// Adds functionalities on top of `Decodable`
public protocol Dekodable: Decodable {
    init()
    mutating func decode(from decoder: Decoder) throws
}

public extension Dekodable {
    init(from decoder: Decoder) throws {
        self.init()
        try decode(from: decoder)
    }

    // MARK: Decoding logic

    mutating func decode(from decoder: Decoder) throws {
        do {
            let container = try decoder.anyDecodingContainer()

            if let _ = self as? DebugJSON {
                debugJSONType(from: decoder, for: type(of: self))
            }

            let currentType = try Reflection.typeInformation(of: type(of: self))

            for property in currentType.properties {
                if let decodable = try? property.get(from: self) as? DecodableProperty {
                    try decodeExtendedProperty(decodable, with: property.name, from: container)
                } else {
                    // Ignores all properties that don't conform to `Decodable`
                    guard let decodable = property.type as? Decodable.Type else { return }
                    let value = try decodable.decodeIfPresent(from: container, with: property.name) as Any
                    try property.set(value: value, on: &self)
                }
            }
        } catch {
            throw KodableError.failedDecodingType(type: type(of: self), underlyingError: .create(from: error))
        }
    }

    private func decodeExtendedProperty(_ property: DecodableProperty, with propertyName: String, from container: DecodeContainer) throws {
        var name = propertyName
        if name.hasPrefix("_") { // Property wrappers start by "_", hence we remove that
            name = String(name.dropFirst())
        }
        try property.decodeValueForProperty(with: name, from: container)
    }
}

// MARK: Extended Encodable Protocol

/// Adds functionalities on top of `Encodable`
public protocol Enkodable: Encodable {}

public extension Enkodable {
    // MARK: Main Encoding Logic

    func encode(to encoder: Encoder) throws {
        var container = encoder.anyEncodingContainer()
        var mirror: Mirror? = Mirror(reflecting: self)

        while true {
            guard let children = mirror?.children else { break }

            for child in children where child.label != nil {
                var propertyName = child.label! // Nil values are removed in guard above
                if propertyName.hasPrefix("_") { // Property wrappers start by "_", hence we remove that
                    propertyName = String(propertyName.dropFirst())
                }

                if let encodableProperty = child.value as? EncodableProperty {
                    try encodableProperty.encodeValueFromProperty(with: propertyName, to: &container)
                } else if let encodableValue = child.value as? Encodable {
                    try encodableValue.encodeIfPresent(to: &container, with: propertyName)
                }
                // Ignores all properties that don't conform to `Encodable`
            }

            mirror = mirror?.superclassMirror
        }
    }
}

// MARK: Enhanced Foundation Codable

public typealias Kodable = Dekodable & Enkodable

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
protocol Dekodable: Decodable {
    init()
    mutating func decode(from decoder: Decoder) throws
}

extension Dekodable {
    init(from decoder: Decoder) throws {
        self.init()
        try decode(from: decoder)
    }

    // MARK: Decoding logic

    mutating func decode(from decoder: Decoder) throws {
        let container = try decoder.anyDecodingContainer()
        var mirror: Mirror? = Mirror(reflecting: self)

        while true {
            guard let children = mirror?.children.filter({ $0.label != nil }) else { break }

            for child in children {
                let name = child.label! // Nil values are removed in guard above
                if let decodable = child.value as? DecodableProperty {
                    try decodeExtendedProperty(decodable, with: name, from: container)
                } else {
                    guard let type = mirror?.subjectType else { continue }
                    try decodeRegularProperty(with: name, from: container, for: type)
                }
            }

            mirror = mirror?.superclassMirror
        }
    }

    private func decodeExtendedProperty(_ property: DecodableProperty, with propertyName: String, from container: DecodeContainer) throws {
        var name = propertyName
        if name.hasPrefix("_") { // Property wrappers start by "_", hence we remove that
            name = String(name.dropFirst())
        }
        try property.decodeValueForProperty(with: name, from: container)
    }

    private mutating func decodeRegularProperty(with propertyName: String, from container: DecodeContainer, for type: Any.Type) throws {
        let typeInfo = try Reflection.typeInformation(of: type)
        let property = try typeInfo.property(named: propertyName)

        // Ignores all properties that don't conform to `Decodable`
        guard let decodable = property.type as? Decodable.Type else { return }

        let value = try decodable.decodeIfPresent(from: container, with: propertyName) as Any
        try property.set(value: value, on: &self)
    }
}

// MARK: Extended Encodable Protocol

/// Adds functionalities on top of `Encodable`
protocol Enkodable: Encodable {}

extension Enkodable {
    // MARK: Main Encoding Logic

    func encode(to encoder: Encoder) throws {
        var container = encoder.anyEncodingContainer()
        var mirror: Mirror? = Mirror(reflecting: self)

        while true {
            guard let children = mirror?.children.filter({ $0.label != nil }) else { break }

            for child in children {
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

typealias Kodable = Dekodable & Enkodable

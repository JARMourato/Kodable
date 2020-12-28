import Foundation

public extension Decodable {
    static func decodeJSON(from data: Data,
                           dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
                           keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) throws -> Self
    {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
        return try decoder.decode(Self.self, from: data)
    }
}

public extension Encodable {
    func encodeJSON(dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
                    keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys) throws -> Data
    {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = dateEncodingStrategy
        encoder.keyEncodingStrategy = keyEncodingStrategy
        return try encoder.encode(self)
    }
}

import Foundation

// MARK: - KodableError

/// Custom errors that `ExtendedCodable` throws when parsing
public enum KodableError: Error {
    /// Thrown whenever the format of the JSON value cannot be decoded into the Type of the property
    case failedToParseDate(source: String)
    /// Thrown whenever the format of the JSON value cannot be decoded into the Type of the property
    case invalidValueForPropertyWithKey(_ key: String)
    /// Thrown whenever a non-optional property marked with JSON is not present in the JSON data and there is no default value to fall back to.
    case nonOptionalValueMissing(property: String)
    /// Thrown whenever there is at least one validation modifier that fails the validation of the value parsed
    case validationFailed(property: String, parsedValue: Any)
}

// MARK: Helper extensions

extension KodableError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .failedToParseDate(source):
            return "Failed to parse the date from the string with value: \(source)"
        case let .invalidValueForPropertyWithKey(key):
            return "The property with key \"\(key)\" cannot be parsed because the json data isn’t in the correct format"
        case let .nonOptionalValueMissing(propertyName):
            return "The property \(propertyName) was marked as non-optional but it is not present in the JSON data nor there is a default value to fall back on"
        case let .validationFailed(propertyName, parsedValue):
            return "Validation for the property \(propertyName) failed. The parsed value was \(parsedValue)"
        }
    }
}

extension KodableError: Equatable {
    public static func == (lhs: KodableError, rhs: KodableError) -> Bool {
        switch (lhs, rhs) {
        case
            let (.invalidValueForPropertyWithKey(lhsName), .invalidValueForPropertyWithKey(rhsName)),
            let (.failedToParseDate(lhsName), .failedToParseDate(rhsName)),
            let (.nonOptionalValueMissing(lhsName), .nonOptionalValueMissing(rhsName)),
            let (.validationFailed(lhsName, _), .validationFailed(rhsName, _)):
            return lhsName == rhsName
        default: return false
        }
    }
}

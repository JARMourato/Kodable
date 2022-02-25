import Foundation

// MARK: - KodableError

/// Custom errors that `ExtendedCodable` throws when parsing
public enum KodableError: Error {
    /// Thrown whenever the string cannot be parsed into a date
    case failedToParseDate(source: String)
    /// Thrown whenever the format of the JSON value cannot be decoded into the Type of the property
    case invalidValueForPropertyWithKey(_ key: String, underlyingError: Error?)
    /// Thrown whenever a non-optional property marked with JSON is not present in the JSON data and there is no default value to fall back to.
    case nonOptionalValueMissing(property: String, type: Any, underlyingError: Error?)
    /// Thrown whenever there is at least one validation modifier that fails the validation of the value parsed
    case validationFailed(property: String, parsedValue: Any)
}

// MARK: Helper extensions

extension KodableError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .failedToParseDate(source):
            return "Failed to parse the date from the string with value: \(source)"
        case let .invalidValueForPropertyWithKey(key, _):
            return "The property with key \"\(key)\" cannot be parsed because the json data isn’t in the correct format.\n\nRaw error: \(underlyingErrorDescription)"
        case let .nonOptionalValueMissing(propertyName, type, _):
            return "The property \(propertyName) for type \(type) was marked as non-optional but it is not present in the JSON data nor there is a default value to fall back on.\n\nRaw error: \(underlyingErrorDescription)"
        case let .validationFailed(propertyName, parsedValue):
            return "Validation for the property \(propertyName) failed. The parsed value was \(parsedValue)"
        }
    }

    internal var underlyingErrorDescription: String {
        var error: Error?
        switch self {
        case .failedToParseDate(_): break
        case let .invalidValueForPropertyWithKey(_, underlyingError): fallthrough
        case let .nonOptionalValueMissing(_, _, underlyingError):
            error = underlyingError
        case .validationFailed(_, _): break
        }
        guard let error = error else { return "N/A" }
        return "\(error)"
    }
}

extension KodableError: Equatable {
    public static func == (lhs: KodableError, rhs: KodableError) -> Bool {
        switch (lhs, rhs) {
        case
            let (.invalidValueForPropertyWithKey(lhsName, _), .invalidValueForPropertyWithKey(rhsName, _)),
            let (.failedToParseDate(lhsName), .failedToParseDate(rhsName)),
            let (.nonOptionalValueMissing(lhsName, _, _), .nonOptionalValueMissing(rhsName, _, _)),
            let (.validationFailed(lhsName, _), .validationFailed(rhsName, _)):
            return lhsName == rhsName
        default: return false
        }
    }
}

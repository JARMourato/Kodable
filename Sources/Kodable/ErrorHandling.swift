import Foundation

// MARK: - Public API Errors
public enum KodableError: Error {
    case failedToDecode(type: Any, underlyingError: Error)
}

extension KodableError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .failedToDecode(type, underlyingError):
            return "Failed to decode an intance of \(type) due to:\n\(underlyingError)"
        }
    }
}


// MARK: - Internal Error Handling

/// Custom errors that `ExtendedCodable` throws when parsing
public indirect enum InternalError: Error {
    /// Wrapper for errors outside Kodable (i.e. decoder/encoder)
    case externalError(Error)
    /// Thrown whenever the string cannot be parsed into a date
    case failedToParseDate(source: String)
    /// Thrown whenever the format of the JSON value cannot be decoded into the Type of the property
    case invalidValueForPropertyWithKey(_ key: String, type: Any, underlyingError: InternalError)
    /// Thrown whenever a non-optional property marked with JSON is not present in the JSON data and there is no default value to fall back to.
    case nonOptionalValueMissing(property: String, type: Any, underlyingError: InternalError?)
    /// Thrown whenever there is at least one validation modifier that fails the validation of the value parsed
    case validationFailed(property: String, parsedValue: Any)
}

// MARK: Helper extensions

extension InternalError: CustomStringConvertible {
    public var description: String {
        buildErrorMessage(nextError: self)
    }

    internal var underlyingError: InternalError? {
        switch self {
        case .failedToParseDate(_), .validationFailed(_, _), .externalError(_): return nil
        case let .invalidValueForPropertyWithKey(_, _, underlyingError): return underlyingError
        case let .nonOptionalValueMissing(_, _, underlyingError): return underlyingError
        }
    }

    internal var underlyingErrorDescription: String {
        guard let error = underlyingError else { return "" }
        return "\n\nUnderlying error: \(error)"
    }

    internal func buildErrorMessage(initial: String = "", nextError: InternalError?) -> String {
        guard let nextError = nextError else { return initial }
        let result = initial + "\n\n" + nextError.errorDescription
        return buildErrorMessage(initial: result, nextError: nextError.underlyingError)
    }

    internal var errorDescription: String {
        switch self {
        case let .failedToParseDate(source):
            return "Failed to parse the date from the string with value: \(source)"
        case let .invalidValueForPropertyWithKey(key, type, _):
            return "The property with key \"\(key)\" for type \(type) cannot be parsed because the json data isn’t in the correct format.\(underlyingErrorDescription)"
        case let .nonOptionalValueMissing(propertyName, type, _):
            return "The property \(propertyName) for type \(type) was marked as non-optional but it is not present in the JSON data nor there is a default value to fall back on.\(underlyingErrorDescription)"
        case let .validationFailed(propertyName, parsedValue):
            return "Validation for the property \(propertyName) failed. The parsed value was \(parsedValue)"
        case .externalError(let error):
            return "\(error)"
        }
    }
}

extension InternalError: Equatable {
    public static func == (lhs: InternalError, rhs: InternalError) -> Bool {
        switch (lhs, rhs) {
        case
            let (.invalidValueForPropertyWithKey(lhsName, _, _), .invalidValueForPropertyWithKey(rhsName, _, _)),
            let (.failedToParseDate(lhsName), .failedToParseDate(rhsName)),
            let (.nonOptionalValueMissing(lhsName, _, _), .nonOptionalValueMissing(rhsName, _, _)),
            let (.validationFailed(lhsName, _), .validationFailed(rhsName, _)):
            return lhsName == rhsName
        default: return false
        }
    }
}

import Foundation

public enum KodableError: Error {
    /// Wrapper for errors thrown by the decoder
    case wrappedError(Error)
    /// Thrown whenever there is no data for a required property
    case dataNotFound
    /// Thrown whenever the string cannot be parsed into a date
    case failedToParseDate(source: String)
    /// Thrown whenever there is at least one validation modifier that fails the validation of the value parsed
    case validationFailed(type: Any, property: String, parsedValue: Any)
    /// Thrown whenever a property cannot be decoded
    indirect case failedDecodingProperty(property: String, key: String, type: Any, underlyingError: KodableError)
    /// Thrown whenever a Type cannot be decoded
    indirect case failedDecodingType(type: Any, underlyingError: KodableError)
}

// MARK: Helper extensions

extension KodableError: CustomStringConvertible {
    public var description: String {
        stringErrorTree(for: self)
    }

    internal func stringErrorTree(for error: KodableError?, initial: String = "", tabs: Int = 0) -> String {
        if error == nil { return initial }
        let message = initial + String(repeating: "   ", count: tabs) + "\(error?.errorDescription ?? "")\n"
        return stringErrorTree(for: error?.nextWrapper, initial: message, tabs: tabs + 1)
    }

    internal var nextWrapper: KodableError? {
        switch self {
        case let .failedDecodingProperty(_, _, _, underlyingError):
            return underlyingError
        case let .failedDecodingType(_, underlyingError):
            return underlyingError
        case .failedToParseDate, .validationFailed, .dataNotFound:
            return nil
        case let .wrappedError(error):
            guard let dekodingError = error as? KodableError else { return nil }
            return dekodingError
        }
    }

    internal var hasKodableErrorChildrenErrors: Bool {
        switch nextWrapper {
        case nil: return false
        case let .wrappedError(error):
            guard let _ = error as? KodableError else { return false }
            return true
        default: return true
        }
    }

    internal var errorDescription: String {
        switch self {
        case let .wrappedError(error):
            return hasKodableErrorChildrenErrors ? "" : "Cause: \(BetterDecodingError(with: error).description)"
        case .dataNotFound:
            return "Missing key (or null value) for property marked as required."
        case let .failedToParseDate(source):
            return "Could not parse Date from this value: \(source)"
        case let .validationFailed(type, property, parsedValue):
            return "Validation failed for property \"\(property)\" on type \"\(type)\". The parsed value was \(parsedValue)"
        case let .failedDecodingProperty(property, key, type, _):
            if hasKodableErrorChildrenErrors {
                return "Error on property named \"\(property)\" with key \"\(key)\" of type \"\(type)\""
            } else {
                return "Could not decode type \"\(type)\". Failed to decode property \"\(property)\" for key \"\(key)\""
            }
        case let .failedDecodingType(type, _):
            return hasKodableErrorChildrenErrors ? "Failure on \"\(type)\"" : "Could not decode an instance of \"\(type)\""
        }
    }
}

// MARK: - Helper init

extension KodableError {
    static func create(from error: Error) -> KodableError {
        guard let kodableError = error as? KodableError else { return .wrappedError(error) }
        return kodableError
    }
}

// MARK: - Conformance to Equatable for testing purposes

extension KodableError: Equatable {
    public static func == (lhs: KodableError, rhs: KodableError) -> Bool {
        switch (lhs, rhs) {
        case let (.wrappedError(lhsError), .wrappedError(rhsError)):
            guard let lhsKodableError = lhsError as? KodableError, let rhsKodableError = rhsError as? KodableError else {
                return lhsError.localizedDescription == rhsError.localizedDescription // A bit dumb but 🤷🏻‍♂️
            }
            return lhsKodableError == rhsKodableError
        case (.dataNotFound, .dataNotFound):
            return true
        case let (.failedToParseDate(lhsSource), .failedToParseDate(rhsSource)):
            return lhsSource == rhsSource
        case (let .validationFailed(_, lhsProperty, _), let .validationFailed(_, rhsProperty, _)):
            return lhsProperty == rhsProperty
        case (let .failedDecodingProperty(lhsProperty, _, lhsType, lhsUnderlyingError), let .failedDecodingProperty(rhsProperty, _, rhsType, rhsUnderlyingError)):
            return "\(lhsType)" == "\(rhsType)" && lhsProperty == rhsProperty && lhsUnderlyingError == rhsUnderlyingError
        case let (.failedDecodingType(lhsType, lhsError), .failedDecodingType(rhsType, rhsError)):
            return "\(lhsType)" == "\(rhsType)" && rhsError == lhsError
        default:
            return false
        }
    }
}

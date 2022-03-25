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
        iterateOverErrors(nextError: self)
    }

    internal var nextIteration: (Node, KodableError)? {
        switch self {
        case let .failedDecodingProperty(property, key, type, underlyingError):
            return (Node(type: type, propertyName: property, key: key), underlyingError)
        case let .failedDecodingType(_, underlyingError):
            return underlyingError.nextIteration
        case .failedToParseDate, .validationFailed, .dataNotFound:
            return nil
        case let .wrappedError(error):
            guard let dekodingError = error as? KodableError else { return nil }
            guard case let .failedDecodingType(type, underlyingError) = dekodingError else {
                return dekodingError.nextIteration
            }
            return (Node(type: type, propertyName: "", key: ""), underlyingError)
        }
    }

    internal func iterateOverErrors(initial nodes: [Node] = [], nextError: KodableError) -> String {
        let initialString = nodes.isEmpty ? "\(nextError.errorDescription)" : "" // Nodes being empty means it is the root error
        guard let next = nextError.nextIteration else { return initialString + buildErrorMessage(nodes: nodes, error: nextError) }
        return initialString + iterateOverErrors(initial: nodes + [next.0], nextError: next.1)
    }

    internal func buildErrorMessage(nodes: [Node], error: KodableError) -> String {
        let spacing = "  "
        var string = ""
        for i in 0 ... nodes.count {
            let spaces = Array(repeating: spacing, count: i + 1).joined(separator: "")
            if i == nodes.count {
                string += "\n\(error.errorDescription)\n\n"
            } else {
                string += "\(spaces)\(nodes[i])\n"
            }
        }
        return string
    }

    internal var errorDescription: String {
        switch self {
        case let .wrappedError(error):
            return "Cause: \(BetterDecodingError(with: error).description)"
        case .dataNotFound:
            return "Missing key (or null value) for property marked as required."
        case let .failedToParseDate(source):
            return "Could not parse Date from this value: \(source)"
        case let .validationFailed(type, property, parsedValue):
            return "Could not decode type \(type). Validation for the property \(property) failed. The parsed value was \(parsedValue)"
        case let .failedDecodingProperty(property, key, type, _):
            return "Could not decode type \(type). Failed to decode property \(property) for key \(key)"
        case let .failedDecodingType(type, _):
            return "Could not decode an instance of \(type):\n"
        }
    }

    internal struct Node: CustomStringConvertible {
        let type: Any
        let propertyName: String
        let key: String

        var description: String {
            guard !propertyName.isEmpty else { return "* failing type \(type)" }
            guard propertyName != key else { return "* failing property: \"\(propertyName)\" of type \(type)" }
            return "* failing property: \"\(propertyName)\"(key: \"\(key)\") of type \(type)"
        }
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

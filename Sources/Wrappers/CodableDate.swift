import Foundation

// MARK: - Date Handling

// MARK: Date Transformable

/// A helper wrapper to facilitate encoding/decoding dates. If no strategy is passed, iso8601 is used by default.
/// The types that use this helper need to conform to `Kodable`  to be able to be correctly decoded/encoded.
@propertyWrapper public final class CodableDate<T: DateProtocol>: KodableTransformable<DateTransformer<T>> {
    override public var wrappedValue: T {
        get { super.wrappedValue }
        set { super.wrappedValue = newValue }
    }

    // MARK: Public Initializers

    override public init() {
        super.init()
    }

    public init(_ modifiers: KodableModifier<T>..., default value: T? = nil) {
        super.init(key: nil, modifiers: modifiers, defaultValue: value)
    }

    public init(_ key: String, _ modifiers: KodableModifier<T>..., default value: T? = nil) {
        super.init(key: key, modifiers: modifiers, defaultValue: value)
    }

    public init(_ strategy: DateCodingStrategy, _ key: String? = nil, _ modifiers: KodableModifier<T>..., default value: T? = nil) {
        super.init(key: key, modifiers: modifiers, defaultValue: value)
        transformer.strategy = strategy
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
}

// MARK: Conforming to CodableTransform

public struct DateTransformer<T: DateProtocol>: KodableTransform {
    internal var strategy: DateCodingStrategy = .iso8601

    public func transformFromJSON(value: String?) throws -> T {
        let dateValue = strategy.date(from: value ?? "")
        let typeIsOptional = try Reflection.typeInformation(of: T.self).kind == .optional

        guard !typeIsOptional, dateValue == nil else { return dateValue as! T }
        throw KodableError.failedToParseDate(source: value ?? "nil")
    }

    public func transformToJSON(value: T) throws -> String? {
        guard let dateValue = value as? Date else { return nil }
        return strategy.string(from: dateValue)
    }

    public init() {}
}

// MARK: - Helper Types

// MARK: Helper Protocol

public protocol DateProtocol {}

extension Date: DateProtocol {}
extension Optional: DateProtocol where Wrapped == Date {}

// MARK: Coding Strategy

public enum DateCodingStrategy {
    case format(String)
    case iso8601
    case rfc2822
    case rfc3339
    case timestamp

    internal func date(from value: String) -> Date? {
        switch self {
        case let .format(format): return DateCodingStrategy.getFormatter(format).date(from: value)
        case .iso8601: return DateCodingStrategy.iso8601Formatter.date(from: value)
        case .rfc2822: return DateCodingStrategy.rfc2822Formatter.date(from: value)
        case .rfc3339: return DateCodingStrategy.rfc3339Formatter.date(from: value)
        case .timestamp:
            guard let timestamp = Double(value) else { return nil }
            return Date(timeIntervalSince1970: timestamp)
        }
    }

    internal func string(from date: Date) -> String {
        switch self {
        case let .format(format): return DateCodingStrategy.getFormatter(format).string(from: date)
        case .iso8601: return DateCodingStrategy.iso8601Formatter.string(from: date)
        case .rfc2822: return DateCodingStrategy.rfc2822Formatter.string(from: date)
        case .rfc3339: return DateCodingStrategy.rfc3339Formatter.string(from: date)
        case .timestamp: return "\(date.timeIntervalSince1970)"
        }
    }

    private static let iso8601Formatter = ISO8601DateFormatter()
    private static let rfc2822Formatter: DateFormatter = getFormatter("EEE, d MMM y HH:mm:ss zzz")
    private static let rfc3339Formatter: DateFormatter = getFormatter("yyyy-MM-dd'T'HH:mm:ssZ")
    private static var formatters: [String: Formatter] = [:]

    private static func getFormatter(_ dateFormat: String) -> DateFormatter {
        if let cachedFormatter = formatters[dateFormat] as? DateFormatter {
            return cachedFormatter
        }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = dateFormat
        formatters[dateFormat] = dateFormatter
        return dateFormatter
    }
}

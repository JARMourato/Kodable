import Foundation

// MARK: - Date Handling

// MARK: Date Transformable

/// A helper wrapper to facilitate encoding/decoding dates. If no strategy is passed, iso8601 is used by default.
/// The types that use this helper need to conform to `Kodable`  to be able to be correctly decoded/encoded.
@propertyWrapper public struct CodableDate<T: DateProtocol>: Codable {
    private var inner: KodableTransformable<DateTransformer<T>>

    public var wrappedValue: T {
        get { inner.wrappedValue }
        set { inner.wrappedValue = newValue }
    }

    public var projectedValue: Self { self }

    public init() {
        self.inner = KodableTransformable()
    }

    public init(_ options: KodableOption<T>..., default value: T? = nil) {
        self.inner = KodableTransformable(options: options, defaultValue: value)
    }

    public init(_ key: String, _ options: KodableOption<T>..., default value: T? = nil) {
        self.inner = KodableTransformable(key: key, options: options, defaultValue: value)
    }

    public init(_ strategy: DateCodingStrategy, _ key: String? = nil, _ options: KodableOption<T>..., default value: T? = nil) {
        self.inner = KodableTransformable(key: key, options: options, defaultValue: value)
        inner.transformer.strategy = strategy
    }

    public init(from decoder: Decoder) throws {
        self.inner = try KodableTransformable(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try inner.encode(to: encoder)
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
    /// Custom date formatter.
    case format(String)
    /// Uses the iOS native `ISO8601DateFormatter`.
    case iso8601
    /// Uses the iOS native `ISO8601DateFormatter` with `DateFormatter.Options.withFractionalSeconds`.
    /// - Note: If you pass a date with greater precision than milliseconds, it will truncate and parse up to milliseconds only. So "2021-08-30T18:35:19.209999Z" would end up being parsed as "2021-08-30T18:35:19.209Z".
    case iso8601WithMillisecondPrecision
    /// Implements the RFC2822 date format: "EEE, d MMM y HH:mm:ss zzz"
    /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc2822
    case rfc2822
    /// Implements the RFC3339 date format: "yyyy-MM-dd'T'HH:mm:ssZ"
    /// - SeeAlso: https://datatracker.ietf.org/doc/html/rfc3339
    case rfc3339
    /// Time interval since 1970.
    case timestamp
    /// A custom date parser to be used, instead of a string formatter.
    /// - Note: it's strongly advised that your implementation of DateConvertible converts to and from Date in a lossless manner, although not required.
    case custom(DateConvertible)

    public func date(from value: String) -> Date? {
        switch self {
        case let .format(format): return DateCodingStrategy.getFormatter(format).date(from: value)
        case .iso8601: return DateCodingStrategy.iso8601Formatter.date(from: value)
        case .iso8601WithMillisecondPrecision: return DateCodingStrategy.iso8601WithFractionalSecondsFormatter.date(from: value)
        case .rfc2822: return DateCodingStrategy.rfc2822Formatter.date(from: value)
        case .rfc3339: return DateCodingStrategy.rfc3339Formatter.date(from: value)
        case .timestamp:
            guard let timestamp = Double(value) else { return nil }
            return Date(timeIntervalSince1970: timestamp)
        case let .custom(parser): return parser.date(from: value)
        }
    }

    public func string(from date: Date) -> String {
        switch self {
        case let .format(format): return DateCodingStrategy.getFormatter(format).string(from: date)
        case .iso8601: return DateCodingStrategy.iso8601Formatter.string(from: date)
        case .iso8601WithMillisecondPrecision: return DateCodingStrategy.iso8601WithFractionalSecondsFormatter.string(from: date)
        case .rfc2822: return DateCodingStrategy.rfc2822Formatter.string(from: date)
        case .rfc3339: return DateCodingStrategy.rfc3339Formatter.string(from: date)
        case .timestamp: return "\(date.timeIntervalSince1970)"
        case let .custom(parser): return parser.string(from: date)
        }
    }

    private static let iso8601Formatter = ISO8601DateFormatter()
    private static let iso8601WithFractionalSecondsFormatter: ISO8601DateFormatter = {
        let result = ISO8601DateFormatter()
        result.formatOptions.insert(.withFractionalSeconds)
        return result
    }()

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

public protocol DateConvertible {
    func date(from value: String) -> Date?
    func string(from date: Date) -> String
}

// MARK: - Decoding Property

extension CodableDate: DecodableProperty where T: Decodable {
    mutating func decodeValueForProperty(with propertyName: String, from container: DecodeContainer) throws {
        try inner.decodeValueForProperty(with: propertyName, from: container)
    }
}

// MARK: - Encoding Property

extension CodableDate: EncodableProperty where T: Encodable {
    func encodeValueFromProperty(with propertyName: String, to container: inout EncodeContainer) throws {
        try inner.encodeValueFromProperty(with: propertyName, to: &container)
    }
}

// MARK: Equatable Conformance

extension CodableDate: Equatable where T: Equatable {
    public static func == (lhs: CodableDate<T>, rhs: CodableDate<T>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

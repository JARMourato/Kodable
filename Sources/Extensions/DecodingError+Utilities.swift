// Copyright © 2022 Rare Edition, Inc. All rights reserved.

import Foundation

// Borrowed from here https://gist.github.com/nunogoncalves/4852077f4e576872f72b70d9e79942f3 🙌🏻
enum BetterDecodingError: CustomStringConvertible {
    case dataCorrupted(_ message: String)
    case keyNotFound(_ message: String)
    case typeMismatch(_ message: String)
    case valueNotFound(_ message: String)
    case any(_ error: Error)

    init(with error: Error) {
        guard let decodingError = error as? DecodingError else {
            self = .any(error)
            return
        }

        switch decodingError {
        case let .dataCorrupted(context):
            let debugDescription = (context.underlyingError as NSError?)?.userInfo["NSDebugDescription"] ?? ""
            self = .dataCorrupted("Data corrupted. \(context.debugDescription) \(debugDescription)")
        case let .keyNotFound(key, context):
            self = .keyNotFound("Key not found. Expected -> \(key.stringValue) <- at: \(context.prettyPath())")
        case let .typeMismatch(_, context):
            self = .typeMismatch("Type mismatch. \(context.debugDescription), at: \(context.prettyPath())")
        case let .valueNotFound(_, context):
            self = .valueNotFound("Value not found. -> \(context.prettyPath()) <- \(context.debugDescription)")
        @unknown default:
            self = .any(error)
        }
    }

    var description: String {
        switch self {
        case let .dataCorrupted(message), let .keyNotFound(message), let .typeMismatch(message), let .valueNotFound(message):
            return message
        case let .any(error):
            return error.localizedDescription
        }
    }
}

extension DecodingError.Context {
    func prettyPath(separatedBy _: String = ".") -> String {
        codingPath.map(\.stringValue).joined(separator: ".")
    }
}

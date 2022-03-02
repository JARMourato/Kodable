import Foundation

struct FailableExpressionWithFallbackError: Swift.Error {
    let main: Swift.Error
    let fallback: Swift.Error
}

// MARK: Helper extensions

extension FailableExpressionWithFallbackError: LocalizedError {
    var errorDescription: String? {
        """
        Main error was:
        \(main)

        Fallback expression error was:
        \(fallback)
        """
    }
}

internal func failableExpression<T>(_ expression: @autoclosure () throws -> T, withFallback fallback: @autoclosure () throws -> T) throws -> T {
    do {
        return try expression()
    } catch let firstError {
        do {
            return try fallback()
        } catch let secondError {
            throw FailableExpressionWithFallbackError(main: firstError, fallback: secondError)
        }
    }
}

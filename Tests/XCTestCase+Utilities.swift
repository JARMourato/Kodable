@testable import Kodable
import XCTest

extension XCTestCase {
    func assert<T, E: Error & Equatable>(_ expression: @autoclosure () throws -> T, throws error: E, in file: StaticString = #file, line: UInt = #line) {
        var thrownError: Error?
        XCTAssertThrowsError(try expression(), file: file, line: line) { thrownError = $0 }
        XCTAssertTrue(thrownError is E, "Unexpected error type: \(type(of: thrownError))", file: file, line: line)
        XCTAssertEqual(thrownError as? E, error, file: file, line: line)
        XCTAssertEqual(thrownError?.localizedDescription, (thrownError as? E)?.localizedDescription)
    }
}

// MARK: - Test purposes extensions

extension FailableExpressionWithFallbackError: Equatable {
    var errorTypes: String {
        "\(main.localizedDescription)\(fallback.localizedDescription)"
    }

    public static func == (lhs: FailableExpressionWithFallbackError, rhs: FailableExpressionWithFallbackError) -> Bool {
        lhs.errorTypes == rhs.errorTypes
    }
}

extension KodableError.Node: Equatable {
    public static func == (lhs: KodableError.Node, rhs: KodableError.Node) -> Bool {
        lhs.description == rhs.description
    }
}

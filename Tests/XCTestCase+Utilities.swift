import XCTest

extension XCTestCase {
    func assert<T, E: Swift.Error & Equatable>(_ expression: @autoclosure () throws -> T, throws error: E, in file: StaticString = #file, line: UInt = #line) {
        var thrownError: Swift.Error?
        XCTAssertThrowsError(try expression(), file: file, line: line) { thrownError = $0 }
        XCTAssertTrue(thrownError is E, "Unexpected error type: \(type(of: thrownError))", file: file, line: line)
        XCTAssertEqual(thrownError as? E, error, file: file, line: line)
        XCTAssertEqual(thrownError?.localizedDescription, (thrownError as? E)?.localizedDescription)
    }
}

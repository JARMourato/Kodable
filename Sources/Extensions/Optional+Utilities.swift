import Foundation

// MARK: Remove double optionals

private protocol Flattenable {
    func flattened() -> Any?
}

extension Optional: Flattenable {
    func flattened() -> Any? {
        switch self {
        case let .some(value as Flattenable):
            return value.flattened()
        case let .some(value):
            return value
        case .none:
            return nil
        }
    }
}

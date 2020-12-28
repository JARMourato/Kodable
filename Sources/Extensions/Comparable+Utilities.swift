import Foundation

extension Comparable {
    /// Returns the value constrained to be within the given range.
    func constrained(to range: ClosedRange<Self>) -> Self {
        if self < range.lowerBound { return range.lowerBound }
        if self > range.upperBound { return range.upperBound }
        return self
    }

    /// Returns the value constrained to be greater than or equal to the given minimum.
    func constrained(toAtLeast min: Self) -> Self {
        self < min ? min : self
    }

    /// Returns the value constrained to be less than or equal to the given maximum.
    func constrained(toAtMost max: Self) -> Self {
        self > max ? max : self
    }
}

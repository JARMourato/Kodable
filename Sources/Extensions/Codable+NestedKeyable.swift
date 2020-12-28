import Foundation

// MARK: - Nested Keys

protocol NestedKeyable {}

private extension NestedKeyable {
    func nestedContainerAndKey<T>(
        in container: inout T,
        and nestedKey: NestedStringKey,
        getNestedContainer: (inout T, String) throws -> T
    ) throws -> (container: T, key: String) {
        let topSegmentAndNestedKey = nestedKey.topSegmentAndSubNestedKey()

        guard let nestedCodingKey = topSegmentAndNestedKey?.top, let nextNestedKey = topSegmentAndNestedKey?.nestedKey, !nextNestedKey.isEmpty else {
            // We've reached the final depth of the nested keyPath
            return (container, nestedKey.description)
        }

        var nextContainer = try getNestedContainer(&container, nestedCodingKey)

        return try nestedContainerAndKey(in: &nextContainer, and: nextNestedKey, getNestedContainer: getNestedContainer)
    }
}

// MARK: Nested Containers

extension DecodeContainer: NestedKeyable {
    mutating func nestedContainerAndKey(for nestedKey: String) throws -> (container: DecodeContainer, key: String) {
        try nestedContainerAndKey(in: &self, and: NestedStringKey(nestedKey)) {
            try $0.nestedContainer(forKey: $1)
        }
    }
}

extension EncodeContainer: NestedKeyable {
    mutating func nestedContainerAndKey(for nestedKey: String) throws -> (container: EncodeContainer, key: String) {
        try nestedContainerAndKey(in: &self, and: NestedStringKey(nestedKey)) {
            $0.nestedContainer(forKey: $1)
        }
    }
}

// MARK: NestedStringKey

private struct NestedStringKey {
    let parts: [String.SubSequence]
    var isEmpty: Bool { parts.isEmpty }

    func topSegmentAndSubNestedKey() -> (top: String, nestedKey: NestedStringKey)? {
        guard !isEmpty else { return nil }
        var nestedKeyParts = parts
        let top = String(nestedKeyParts.removeFirst())
        let subNestedKey = NestedStringKey(parts: nestedKeyParts)
        return (top, subNestedKey)
    }
}

extension NestedStringKey {
    init(_ string: String) {
        parts = string.split(separator: ".")
    }
}

extension NestedStringKey: CustomStringConvertible {
    var description: String { parts.joined(separator: ".") }
}

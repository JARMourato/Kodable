import Runtime

public enum Reflection {
    /// Returns information for a given type, such as its properties and its type
    public static func typeInformation(of type: Any.Type) throws -> TypeInfo {
        // Try fetching from the cache first
        let hashedType = HashedType(type)
        if let cached = cachedTypeInfo[hashedType] { return cached }
        // Compute Type Info when needed
        let newTypeInfo = try typeInfo(of: type)
        cachedTypeInfo[hashedType] = newTypeInfo
        return newTypeInfo
    }
}

extension Reflection {
    // Caching for performance
    private struct HashedType: Hashable {
        private var hashKey: Int
        init(_ type: Any.Type) { hashKey = unsafeBitCast(type, to: Int.self) }
        func hash(into hasher: inout Hasher) { hasher.combine(hashKey) }
        static func == (lhs: HashedType, rhs: HashedType) -> Bool { lhs.hashValue == rhs.hashValue }
    }

    private static var cachedTypeInfo: [HashedType: TypeInfo] = [:]
}

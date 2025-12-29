import Foundation
import Runtime

public enum Reflection {
    /// Returns information for a given type, such as its properties and its type
    public static func typeInformation(of type: Any.Type) throws -> TypeInfo {
        let hashedType = HashedType(type)

        // Thread-safe read from cache
        cacheLock.lock()
        if let cached = cachedTypeInfo[hashedType] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        // Compute Type Info outside the lock
        var newTypeInfo = try typeInfo(of: type)

        // As of version Runtime 2.2.2, when there are multiple super classes, properties are duplicated
        var propertyNames: Set<String> = []
        newTypeInfo.properties = newTypeInfo.properties.filter { p in
            guard !propertyNames.contains(p.name) else { return false }
            propertyNames.insert(p.name)
            return true
        }

        // Thread-safe write to cache
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = cachedTypeInfo[hashedType] { return cached }
        cachedTypeInfo[hashedType] = newTypeInfo
        return newTypeInfo
    }
}

extension Reflection {
    private struct HashedType: Hashable {
        private var hashKey: Int
        init(_ type: Any.Type) { hashKey = unsafeBitCast(type, to: Int.self) }
        func hash(into hasher: inout Hasher) { hasher.combine(hashKey) }
        static func == (lhs: HashedType, rhs: HashedType) -> Bool { lhs.hashValue == rhs.hashValue }
    }

    private static let cacheLock = NSLock()
    private static var cachedTypeInfo: [HashedType: TypeInfo] = [:]
}

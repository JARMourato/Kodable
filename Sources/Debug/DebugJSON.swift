import Foundation
import JSEN

public protocol DebugJSON {}

func debugJSONType<T>(from decoder: Decoder, for type: T.Type) {
    let jsen = try? JSEN.init(from: decoder)
    printJSON(jsen, for: nil, with: type)
}

func debugJSONProperty<T>(from container: DecodeContainer, for propertyName: String, with type: T.Type) {
    let jsen = try? container.decode(JSEN.self, with: propertyName)
    printJSON(jsen, for: propertyName, with: type)
}

private func printJSON<T>(_ jsen: JSEN?, for propertyName: String?, with type: T.Type) {
    let debugString = jsen?.prettyPrinted() ?? "Failed to grab JSON"
    let propertyString = propertyName == nil ? "" : "the \(propertyName!) property of "
    print("Decoded JSON for \(propertyString)type \(type):\n\(debugString)\n\n")
}


// MARK: - JSEN Helpers
extension JSEN {
    func prettyPrinted() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try? encoder.encode(self)
        return String(data: data ?? Data(), encoding: .utf8) ?? "Failed to generate JSON string"
    }
}

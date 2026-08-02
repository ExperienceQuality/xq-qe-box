import Foundation

public enum DiffMap {
    public static func refLine(ref: String, entry: [String: JSONValue]) -> String {
        let role = entry["role"]?.stringValue ?? "element"
        let label = entry["label"]?.stringValue ?? ""
        if label.isEmpty {
            return "\(ref) [\(role)]"
        }
        return "\(ref) [\(role)] \"\(label)\""
    }

    public static func summarize(_ document: MapDocument) -> [String] {
        document.refs.keys.sorted {
            let lhs = Int($0.dropFirst(2)) ?? 0
            let rhs = Int($1.dropFirst(2)) ?? 0
            return lhs < rhs
        }.map { refLine(ref: $0, entry: document.refs[$0]?.objectValue ?? [:]) }
    }

    public static func diff(previous: MapDocument, current: MapDocument) -> [String: JSONValue] {
        let previousLines = Set(summarize(previous))
        let currentLines = Set(summarize(current))
        let added = currentLines.subtracting(previousLines).sorted()
        let removed = previousLines.subtracting(currentLines).sorted()
        let unchanged = previousLines.intersection(currentLines).count
        return [
            "added": .array(added.map(JSONValue.string)),
            "removed": .array(removed.map(JSONValue.string)),
            "unchanged": .int(unchanged),
        ]
    }
}

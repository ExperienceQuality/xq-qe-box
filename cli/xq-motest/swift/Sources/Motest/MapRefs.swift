import Foundation

public enum MapRefs {
    private static let actionableRoles: Set<String> = [
        "button", "link", "switch", "textfield", "text field", "securetextfield",
    ]

    public static func assign(_ raw: JSONValue) -> (refs: [String: JSONValue], summary: [String: JSONValue]) {
        var refs: [String: JSONValue] = [:]
        var index = 1

        func walk(_ node: [String: JSONValue], path: [String]) {
            if isActionable(node), let frame = nodeFrame(node), let center = frameCenter(frame) {
                let ref = "@e\(index)"
                refs[ref] = .object([
                    "label": .string(nodeLabel(node)),
                    "role": .string(nodeRole(node).isEmpty ? "element" : nodeRole(node)),
                    "frame": frame,
                    "center": center,
                    "path": .array(path.map(JSONValue.string)),
                ])
                index += 1
            }
            for (childIndex, child) in children(node).enumerated() {
                if let childObject = child.objectValue {
                    walk(childObject, path: path + [String(childIndex)])
                }
            }
        }

        for (rootIndex, root) in roots(raw).enumerated() {
            walk(root, path: [String(rootIndex)])
        }

        let count = refs.count
        let summary: [String: JSONValue] = [
            "count": .int(count),
            "refRange": count > 0
                ? .array([.string("@e1"), .string("@e\(count)")])
                : .array([]),
        ]
        return (refs, summary)
    }

    private static func roots(_ raw: JSONValue) -> [[String: JSONValue]] {
        if let object = raw.objectValue {
            if let tree = object["tree"]?.objectValue {
                return [tree]
            }
            if object["children"] != nil {
                return children(object).compactMap(\.objectValue)
            }
            return [object]
        }
        if let array = raw.arrayValue {
            return array.compactMap(\.objectValue)
        }
        return []
    }

    private static func nodeRole(_ node: [String: JSONValue]) -> String {
        for key in ["role", "type", "elementType"] {
            if let value = node[key]?.stringValue {
                return value.lowercased()
            }
        }
        return ""
    }

    private static func nodeFrame(_ node: [String: JSONValue]) -> JSONValue? {
        if let frame = node["frame"] { return frame }
        return node["rect"]
    }

    private static func frameCenter(_ frame: JSONValue) -> JSONValue? {
        guard let object = frame.objectValue,
              let x = object["x"]?.intValue,
              let y = object["y"]?.intValue else { return nil }
        let width = object["width"]?.intValue ?? object["w"]?.intValue ?? 0
        let height = object["height"]?.intValue ?? object["h"]?.intValue ?? 0
        guard width > 0, height > 0 else { return nil }
        return .object(["x": .int(x + width / 2), "y": .int(y + height / 2)])
    }

    private static func isActionable(_ node: [String: JSONValue]) -> Bool {
        let role = nodeRole(node)
        if actionableRoles.contains(role) { return true }
        if node["isEnabled"] == .bool(false) { return false }
        guard let frame = nodeFrame(node) else { return false }
        return frameCenter(frame) != nil
    }

    private static func nodeLabel(_ node: [String: JSONValue]) -> String {
        for key in ["label", "title", "name", "placeholder", "value"] {
            if let value = node[key]?.stringValue, !value.isEmpty {
                return value
            }
        }
        return ""
    }

    private static func children(_ node: [String: JSONValue]) -> [JSONValue] {
        node["children"]?.arrayValue ?? []
    }
}

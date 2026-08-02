import Foundation

struct MapDocument: Sendable {
    var version: Int
    var createdAt: String
    var baseURL: String
    var bundleID: String?
    var raw: JSONValue
    var refs: [String: JSONValue]
    var summary: [String: JSONValue]

    func toDictionary() -> [String: JSONValue] {
        var dict: [String: JSONValue] = [
            "version": .int(version),
            "createdAt": .string(createdAt),
            "baseUrl": .string(baseURL),
            "raw": raw,
            "refs": .object(refs),
            "summary": .object(summary),
        ]
        if let bundleID {
            dict["bundleId"] = .string(bundleID)
        }
        return dict
    }

    static func fromDictionary(_ data: [String: JSONValue]) -> MapDocument {
        MapDocument(
            version: data["version"]?.intValue ?? 1,
            createdAt: data["createdAt"]?.stringValue ?? "",
            baseURL: data["baseUrl"]?.stringValue ?? "",
            bundleID: data["bundleId"]?.stringValue,
            raw: data["raw"] ?? .null,
            refs: data["refs"]?.objectValue ?? [:],
            summary: data["summary"]?.objectValue ?? [:]
        )
    }
}

struct MapStore: Sendable {
    let stateDir: URL

    init(stateDir: URL) {
        self.stateDir = stateDir
    }

    var mapPath: URL {
        stateDir.appendingPathComponent("last-map.json")
    }

    func save(_ document: MapDocument) throws -> URL {
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: document.toDictionary().mapValues(\.foundationValue),
            options: []
        )
        try data.write(to: mapPath)
        return mapPath
    }

    func load() throws -> MapDocument {
        guard FileManager.default.fileExists(atPath: mapPath.path) else {
            throw MotestError.usage("No saved map found", hint: "xq-motest map")
        }
        let data = try Data(contentsOf: mapPath)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return MapDocument.fromDictionary(JSONValue(any: object).objectValue ?? [:])
    }

    func invalidate() throws {
        if FileManager.default.fileExists(atPath: mapPath.path) {
            try FileManager.default.removeItem(at: mapPath)
        }
    }

    func resolveTap(ref: String?, x: Int?, y: Int?) throws -> [String: JSONValue] {
        if let ref {
            let document = try load()
            guard let entry = document.refs[ref]?.objectValue else {
                throw MotestError.usage("Unknown ref \(ref)", hint: "xq-motest map", command: "tap")
            }
            guard let center = entry["center"]?.objectValue,
                  let cx = center["x"]?.intValue,
                  let cy = center["y"]?.intValue else {
                throw MotestError.usage("Ref \(ref) has no tap target", hint: "xq-motest map", command: "tap")
            }
            return [
                "x": .int(cx),
                "y": .int(cy),
                "deviceId": .string("any"),
            ]
        }
        if let x, let y {
            return ["x": .int(x), "y": .int(y), "deviceId": .string("any")]
        }
        throw MotestError.usage(
            "tap requires @eN or X Y coordinates",
            hint: "xq-motest tap @e3",
            command: "tap"
        )
    }

    func resolveTypeTarget(ref: String?) throws -> [String: JSONValue]? {
        guard let ref else { return nil }
        let document = try load()
        guard let entry = document.refs[ref]?.objectValue else {
            throw MotestError.usage("Unknown ref \(ref)", hint: "xq-motest map", command: "type")
        }
        guard let center = entry["center"]?.objectValue,
              let cx = center["x"]?.intValue,
              let cy = center["y"]?.intValue else {
            return nil
        }
        return ["x": .int(cx), "y": .int(cy), "deviceId": .string("any")]
    }

    func snapshotPreviousMap() throws {
        let previous = stateDir.appendingPathComponent("previous-map.json")
        guard FileManager.default.fileExists(atPath: mapPath.path) else { return }
        if FileManager.default.fileExists(atPath: previous.path) {
            try FileManager.default.removeItem(at: previous)
        }
        try FileManager.default.copyItem(at: mapPath, to: previous)
    }
}

enum MapDocumentFactory {
    static func newDocument(
        baseURL: String,
        bundleID: String?,
        raw: JSONValue,
        refs: [String: JSONValue],
        summary: [String: JSONValue]
    ) -> MapDocument {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return MapDocument(
            version: 1,
            createdAt: formatter.string(from: Date()),
            baseURL: baseURL,
            bundleID: bundleID,
            raw: raw,
            refs: refs,
            summary: summary
        )
    }
}

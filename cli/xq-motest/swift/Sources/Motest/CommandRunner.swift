import Foundation

public enum CommandRunner {
    public static func health(config: Config, transport: any KitTransport) async throws -> [String: JSONValue] {
        let health = try await transport.fetchHealth()
        let result: JSONValue = .object([
            "reachable": .bool(health.ok),
            "statusCode": .int(health.statusCode),
            "baseUrl": .string(config.baseURL),
        ])
        return Envelope.success(
            command: "health",
            result: result,
            baseURL: config.baseURL,
            durationMs: health.durationMs
        )
    }

    public static func rpc(
        config: Config,
        transport: any KitTransport,
        method: String?,
        paramsJSON: String?
    ) async throws -> [String: JSONValue] {
        guard let method, !method.isEmpty else {
            throw CLIError.usage("Missing --method", hint: "xq-motest rpc --method device.dump.ui", command: "rpc")
        }
        let params = try parseParams(paramsJSON)
        let (result, duration) = try await KitCall.call(config: config, transport: transport, method: method, params: params)
        return Envelope.success(
            command: "rpc",
            result: result,
            baseURL: config.baseURL,
            method: method,
            durationMs: duration
        )
    }

    public static func map(
        config: Config,
        transport: any KitTransport,
        includeRaw: Bool = false
    ) async throws -> [String: JSONValue] {
        let (raw, duration) = try await KitCall.call(config: config, transport: transport, method: "device.dump.ui", params: .object([:]))
        let assigned = MapRefs.assign(raw)
        let store = MapStore(stateDir: config.stateDir)
        try store.snapshotPreviousMap()
        let document = MapDocumentFactory.newDocument(
            baseURL: config.baseURL,
            bundleID: nil,
            raw: raw,
            refs: assigned.refs,
            summary: assigned.summary
        )
        let savedPath = try store.save(document)
        var result: [String: JSONValue] = [
            "refs": .object(assigned.refs),
            "summary": .object(assigned.summary),
        ]
        if includeRaw { result["raw"] = raw }
        return Envelope.success(
            command: "map",
            result: .object(result),
            baseURL: config.baseURL,
            method: "device.dump.ui",
            durationMs: duration,
            extraMeta: ["savedPath": .string(savedPath.path)]
        )
    }

    public static func diffMap(config: Config) throws -> [String: JSONValue] {
        let store = MapStore(stateDir: config.stateDir)
        let current = try store.load()
        let previousPath = config.stateDir.appendingPathComponent("previous-map.json")
        guard FileManager.default.fileExists(atPath: previousPath.path) else {
            throw CLIError.usage("No previous map to diff against", hint: "xq-motest map", command: "diff.map")
        }
        let data = try Data(contentsOf: previousPath)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let previous = MapDocument.fromDictionary(JSONValue(any: object).objectValue ?? [:])
        let result = DiffMap.diff(previous: previous, current: current)
        return Envelope.success(command: "diff.map", result: .object(result), baseURL: config.baseURL)
    }

    public static func tap(
        config: Config,
        transport: any KitTransport,
        ref: String?,
        x: Int?,
        y: Int?
    ) async throws {
        let store = MapStore(stateDir: config.stateDir)
        let params = try store.resolveTap(ref: ref, x: x, y: y)
        try await KitCall.action(config: config, transport: transport, method: "device.io.tap", params: .object(params))
        try store.invalidate()
    }

    public static func type(
        config: Config,
        transport: any KitTransport,
        text: String,
        ref: String?
    ) async throws {
        guard !text.isEmpty else {
            throw CLIError.usage("type requires text", hint: "xq-motest type @e2 hello", command: "type")
        }
        let store = MapStore(stateDir: config.stateDir)
        if let target = try store.resolveTypeTarget(ref: ref) {
            try await KitCall.action(config: config, transport: transport, method: "device.io.tap", params: .object(target))
        }
        try await KitCall.action(
            config: config,
            transport: transport,
            method: "device.io.text",
            params: .object(["text": .string(text)])
        )
        try store.invalidate()
    }

    public static func launch(
        config: Config,
        transport: any KitTransport,
        bundleID: String
    ) async throws {
        guard !bundleID.isEmpty else {
            throw CLIError.usage("Missing bundle id", hint: "xq-motest launch com.example.app", command: "launch")
        }
        try await KitCall.action(
            config: config,
            transport: transport,
            method: "device.apps.launch",
            params: .object(["bundleId": .string(bundleID)])
        )
        try MapStore(stateDir: config.stateDir).invalidate()
    }

    public static func dump(config: Config, transport: any KitTransport) async throws -> [String: JSONValue] {
        let (result, duration) = try await KitCall.call(config: config, transport: transport, method: "device.dump.ui", params: .object([:]))
        return Envelope.success(
            command: "dump",
            result: result,
            baseURL: config.baseURL,
            method: "device.dump.ui",
            durationMs: duration
        )
    }

    private static func parseParams(_ paramsJSON: String?) throws -> JSONValue? {
        guard let paramsJSON, !paramsJSON.isEmpty else { return nil }
        do {
            return try JSONValue.decode(from: paramsJSON)
        } catch {
            throw CLIError.usage(
                "Invalid --params JSON: \(error.localizedDescription)",
                hint: #"xq-motest rpc --method device.io.tap --params '{"x":0,"y":0}'"#,
                command: "rpc"
            )
        }
    }
}

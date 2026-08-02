import Foundation

/// Session command surface — every mutation/query agents need.
/// The executable only parses argv, calls these entry points, and maps MotestError via CLIEmit.
public enum CommandRunner {
    // MARK: - Public Session entry points (live DeviceKit transport)

    public static func health(config: Config) async throws -> [String: JSONValue] {
        try await health(config: config, transport: liveTransport(config))
    }

    public static func rpc(
        config: Config,
        method: String?,
        paramsJSON: String?
    ) async throws -> [String: JSONValue] {
        try await rpc(config: config, transport: liveTransport(config), method: method, paramsJSON: paramsJSON)
    }

    public static func map(config: Config, includeRaw: Bool = false) async throws -> [String: JSONValue] {
        try await map(config: config, transport: liveTransport(config), includeRaw: includeRaw)
    }

    public static func diffMap(config: Config) throws -> [String: JSONValue] {
        let store = MapStore(stateDir: config.stateDir)
        let current = try store.load()
        let previousPath = config.stateDir.appendingPathComponent("previous-map.json")
        guard FileManager.default.fileExists(atPath: previousPath.path) else {
            throw MotestError.usage("No previous map to diff against", hint: "xq-motest map", command: "diff.map")
        }
        let data = try Data(contentsOf: previousPath)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let previous = MapDocument.fromDictionary(JSONValue(any: object).objectValue ?? [:])
        let result = DiffMap.diff(previous: previous, current: current)
        return Envelope.success(command: "diff.map", result: .object(result), baseURL: config.baseURL)
    }

    public static func dump(config: Config) async throws -> [String: JSONValue] {
        try await dump(config: config, transport: liveTransport(config))
    }

    public static func devicekitStatus(config: Config, device: String?) async -> [String: JSONValue] {
        let status = await DeviceKitRuntime.status(config: config, device: device)
        let result: JSONValue = .object([
            "installed": .bool(status.installed),
            "bundle_id": status.bundleID.map(JSONValue.string) ?? .null,
            "version": status.version.map(JSONValue.string) ?? .null,
            "server_reachable": .bool(status.serverReachable),
            "base_url": .string(status.baseURL),
            "device_id": status.deviceID.map(JSONValue.string) ?? .null,
            "mode": status.mode.map(JSONValue.string) ?? .null,
        ])
        return Envelope.success(
            command: "devicekit.status",
            result: result,
            baseURL: config.baseURL
        )
    }

    public static func tap(
        config: Config,
        first: String,
        second: String?,
        ref: String?,
        x: Int?,
        y: Int?
    ) async throws {
        try await tap(
            config: config,
            transport: liveTransport(config),
            first: first,
            second: second,
            ref: ref,
            x: x,
            y: y
        )
    }

    public static func type(
        config: Config,
        first: String,
        rest: [String],
        ref: String?
    ) async throws {
        try await type(
            config: config,
            transport: liveTransport(config),
            first: first,
            rest: rest,
            ref: ref
        )
    }

    public static func launch(config: Config, bundleID: String) async throws {
        try await launch(config: config, transport: liveTransport(config), bundleID: bundleID)
    }

    public static func foreground(config: Config) async throws {
        try await foreground(config: config, transport: liveTransport(config))
    }

    public static func screenshot(config: Config, path: String) async throws {
        try await screenshot(config: config, transport: liveTransport(config), path: path)
    }

    public static func devicekitStart(config: Config, sim: Bool, deviceID: String?) async throws {
        try await DeviceKitRuntime.start(config: config, sim: sim, deviceID: deviceID)
    }

    public struct TapTarget: Equatable, Sendable {
        public var ref: String?
        public var x: Int?
        public var y: Int?

        public static func parse(
            first: String,
            second: String?,
            ref: String?,
            x: Int?,
            y: Int?
        ) throws -> TapTarget {
            if let ref {
                return TapTarget(ref: ref, x: x, y: y)
            }
            if first.hasPrefix("@e") {
                return TapTarget(ref: first, x: nil, y: nil)
            }
            if let second, let px = Int(first), let py = Int(second) {
                return TapTarget(ref: nil, x: px, y: py)
            }
            throw MotestError.usage(
                "tap requires @eN or X Y coordinates",
                hint: "xq-motest tap @e3",
                command: "tap"
            )
        }
    }

    public struct TypeInput: Equatable, Sendable {
        public var text: String
        public var ref: String?

        public static func parse(first: String, rest: [String], ref: String?) -> TypeInput {
            if let ref {
                return TypeInput(text: ([first] + rest).joined(separator: " "), ref: ref)
            }
            if first.hasPrefix("@e") {
                return TypeInput(text: rest.joined(separator: " "), ref: first)
            }
            return TypeInput(text: ([first] + rest).joined(separator: " "), ref: nil)
        }
    }

    // MARK: - Internal (injectable transport — tests / advanced)

    static func liveTransport(_ config: Config) -> any KitTransport {
        WSJSONRPCTransport(config: config)
    }

    static func health(config: Config, transport: any KitTransport) async throws -> [String: JSONValue] {
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

    static func rpc(
        config: Config,
        transport: any KitTransport,
        method: String?,
        paramsJSON: String?
    ) async throws -> [String: JSONValue] {
        guard let method, !method.isEmpty else {
            throw MotestError.usage(
                "Missing method",
                hint: "xq-motest rpc device.dump.ui",
                command: "rpc"
            )
        }
        let params = try parseParams(paramsJSON)
        let (result, duration) = try await KitCall.call(
            config: config,
            transport: transport,
            method: method,
            params: params
        )
        return Envelope.success(
            command: "rpc",
            result: result,
            baseURL: config.baseURL,
            method: method,
            durationMs: duration
        )
    }

    static func map(
        config: Config,
        transport: any KitTransport,
        includeRaw: Bool = false
    ) async throws -> [String: JSONValue] {
        let (raw, duration) = try await KitCall.call(
            config: config,
            transport: transport,
            method: "device.dump.ui",
            params: .object([:])
        )
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

    static func dump(config: Config, transport: any KitTransport) async throws -> [String: JSONValue] {
        let (result, duration) = try await KitCall.call(
            config: config,
            transport: transport,
            method: "device.dump.ui",
            params: .object([:])
        )
        return Envelope.success(
            command: "dump",
            result: result,
            baseURL: config.baseURL,
            method: "device.dump.ui",
            durationMs: duration
        )
    }

    static func tap(
        config: Config,
        transport: any KitTransport,
        ref: String?,
        x: Int?,
        y: Int?
    ) async throws {
        let store = MapStore(stateDir: config.stateDir)
        let params = try store.resolveTap(ref: ref, x: x, y: y)
        try await KitCall.action(
            config: config,
            transport: transport,
            method: "device.io.tap",
            params: .object(params)
        )
        try store.invalidate()
    }

    static func tap(
        config: Config,
        transport: any KitTransport,
        first: String,
        second: String?,
        ref: String?,
        x: Int?,
        y: Int?
    ) async throws {
        let target = try TapTarget.parse(first: first, second: second, ref: ref, x: x, y: y)
        try await tap(config: config, transport: transport, ref: target.ref, x: target.x, y: target.y)
    }

    static func type(
        config: Config,
        transport: any KitTransport,
        text: String,
        ref: String?
    ) async throws {
        guard !text.isEmpty else {
            throw MotestError.usage("type requires text", hint: "xq-motest type @e2 hello", command: "type")
        }
        let store = MapStore(stateDir: config.stateDir)
        if let target = try store.resolveTypeTarget(ref: ref) {
            try await KitCall.action(
                config: config,
                transport: transport,
                method: "device.io.tap",
                params: .object(target)
            )
        }
        try await KitCall.action(
            config: config,
            transport: transport,
            method: "device.io.text",
            params: .object(["text": .string(text)])
        )
        try store.invalidate()
    }

    static func type(
        config: Config,
        transport: any KitTransport,
        first: String,
        rest: [String],
        ref: String?
    ) async throws {
        let parsed = TypeInput.parse(first: first, rest: rest, ref: ref)
        try await type(config: config, transport: transport, text: parsed.text, ref: parsed.ref)
    }

    static func launch(
        config: Config,
        transport: any KitTransport,
        bundleID: String
    ) async throws {
        guard !bundleID.isEmpty else {
            throw MotestError.usage("Missing bundle id", hint: "xq-motest launch com.example.app", command: "launch")
        }
        try await KitCall.action(
            config: config,
            transport: transport,
            method: "device.apps.launch",
            params: .object(["bundleId": .string(bundleID)])
        )
        try MapStore(stateDir: config.stateDir).invalidate()
    }

    static func foreground(config: Config, transport: any KitTransport) async throws {
        try await KitCall.action(
            config: config,
            transport: transport,
            method: "device.apps.foreground",
            params: .object([:])
        )
    }

    static func screenshot(
        config: Config,
        transport: any KitTransport,
        path: String
    ) async throws {
        let (result, _) = try await KitCall.call(
            config: config,
            transport: transport,
            method: "device.screenshot",
            params: .object([:])
        )
        let bytes = try extractScreenshotBytes(result)
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try bytes.write(to: url)
    }

    // MARK: - Private

    private static func extractScreenshotBytes(_ result: JSONValue) throws -> Data {
        if case .string(let base64) = result, let data = Data(base64Encoded: base64) {
            return data
        }
        if let object = result.objectValue {
            for key in ["data", "image", "png", "base64"] {
                if case .string(let base64) = object[key], let data = Data(base64Encoded: base64) {
                    return data
                }
            }
        }
        throw MotestError.usage(
            "Unexpected screenshot payload",
            hint: "xq-motest screenshot /tmp/screen.png",
            command: "screenshot"
        )
    }

    private static func parseParams(_ paramsJSON: String?) throws -> JSONValue? {
        guard let paramsJSON, !paramsJSON.isEmpty else { return nil }
        do {
            return try JSONValue.decode(from: paramsJSON)
        } catch {
            throw MotestError.usage(
                "Invalid params JSON: \(error.localizedDescription)",
                hint: #"xq-motest rpc device.io.tap '{"x":0,"y":0}'"#,
                command: "rpc"
            )
        }
    }
}

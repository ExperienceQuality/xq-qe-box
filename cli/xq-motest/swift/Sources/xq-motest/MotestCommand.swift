import ArgumentParser
import Foundation
import Motest

struct GlobalOptions: ParsableArguments {
    @Option(name: .long, help: "DeviceKit HTTP base URL")
    var baseURL: String?

    @Option(name: .long, help: "Timeout in seconds")
    var timeout: Double?

    @Flag(name: .long, help: "Pretty stdout")
    var pretty = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Auto-start DeviceKit when needed")
    var ensureRuntime = true

    @Option(name: .long, help: "State directory")
    var stateDir: String?

    @Option(name: .long, help: "Device UDID override")
    var device: String?

    func makeConfig() -> Config {
        Config.fromEnvironment(
            baseURL: baseURL,
            timeoutSec: timeout,
            pretty: pretty,
            ensureRuntime: ensureRuntime,
            stateDir: stateDir.map { URL(fileURLWithPath: $0, isDirectory: true) },
            deviceID: device
        )
    }
}

@main
struct MotestCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xq-motest",
        abstract: "Agent-native iOS DeviceKit CLI",
        subcommands: [
            Health.self,
            Map.self,
            Diff.self,
            Tap.self,
            TypeText.self,
            Screenshot.self,
            Launch.self,
            Foreground.self,
            Dump.self,
            Rpc.self,
            DeviceKitCommand.self,
        ]
    )
}

struct Health: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Probe DeviceKit /health")

    @OptionGroup var globals: GlobalOptions

    mutating func run() async throws {
        let config = globals.makeConfig()
        let transport = WSJSONRPCTransport(config: config)
        do {
            let envelope = try await CommandRunner.health(config: config, transport: transport)
            Envelope.emit(envelope, pretty: config.pretty, tier: .data)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct Map: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Dump UI and assign @eN refs")

    @OptionGroup var globals: GlobalOptions
    @Flag(name: .long, help: "Include raw DeviceKit tree in result")
    var includeRaw = false

    mutating func run() async throws {
        let config = globals.makeConfig()
        let transport = WSJSONRPCTransport(config: config)
        do {
            let envelope = try await CommandRunner.map(config: config, transport: transport, includeRaw: includeRaw)
            Envelope.emit(envelope, pretty: config.pretty, tier: .data)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct Diff: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Diff commands",
        subcommands: [DiffMap.self]
    )
}

struct DiffMap: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "map", abstract: "Diff current map vs previous")

    @OptionGroup var globals: GlobalOptions

    mutating func run() throws {
        let config = globals.makeConfig()
        do {
            let envelope = try CommandRunner.diffMap(config: config)
            Envelope.emit(envelope, pretty: config.pretty, tier: .data)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct Tap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Tap @eN or X Y")

    @OptionGroup var globals: GlobalOptions
    @Argument(help: "@eN or X coordinate")
    var first: String
    @Argument(help: "Y coordinate when tapping by position")
    var second: String?

    @Option(name: .long, help: "Element ref")
    var ref: String?
    @Option(name: .long, help: "X coordinate")
    var x: Int?
    @Option(name: .long, help: "Y coordinate")
    var y: Int?

    mutating func run() async throws {
        let config = globals.makeConfig()
        let transport = WSJSONRPCTransport(config: config)
        let parsedRef: String?
        let parsedX: Int?
        let parsedY: Int?
        if let ref {
            parsedRef = ref; parsedX = x; parsedY = y
        } else if first.hasPrefix("@e") {
            parsedRef = first; parsedX = nil; parsedY = nil
        } else if let second, let px = Int(first), let py = Int(second) {
            parsedRef = nil; parsedX = px; parsedY = py
        } else {
            Envelope.emitFailure(
                .usage("tap requires @eN or X Y coordinates", hint: "xq-motest tap @e3", command: "tap"),
                pretty: config.pretty
            )
        }
        do {
            try await CommandRunner.tap(config: config, transport: transport, ref: parsedRef, x: parsedX, y: parsedY)
            Envelope.emit(nil, pretty: config.pretty, tier: .action)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct TypeText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "type", abstract: "Type text, optionally after tapping @eN")

    @OptionGroup var globals: GlobalOptions
    @Argument(help: "@eN or text")
    var first: String
    @Argument(parsing: .remaining, help: "Text when first arg is a ref")
    var rest: [String] = []
    @Option(name: .long, help: "Element ref")
    var ref: String?

    mutating func run() async throws {
        let config = globals.makeConfig()
        let transport = WSJSONRPCTransport(config: config)
        let parsedRef: String?
        let text: String
        if let ref {
            parsedRef = ref
            text = ([first] + rest).joined(separator: " ")
        } else if first.hasPrefix("@e") {
            parsedRef = first
            text = rest.joined(separator: " ")
        } else {
            parsedRef = nil
            text = ([first] + rest).joined(separator: " ")
        }
        do {
            try await CommandRunner.type(config: config, transport: transport, text: text, ref: parsedRef)
            Envelope.emit(nil, pretty: config.pretty, tier: .action)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct Screenshot: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Capture screenshot to PATH")

    @OptionGroup var globals: GlobalOptions
    @Argument(help: "Output image path")
    var path: String

    mutating func run() async throws {
        let config = globals.makeConfig()
        let transport = WSJSONRPCTransport(config: config)
        do {
            let (result, _) = try await KitCall.call(
                config: config,
                transport: transport,
                method: "device.screenshot",
                params: .object([:])
            )
            let bytes = try extractScreenshotBytes(result)
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: url)
            Envelope.emit(nil, pretty: config.pretty, tier: .action)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }

    private func extractScreenshotBytes(_ result: JSONValue) throws -> Data {
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
        throw CLIError.usage("Unexpected screenshot payload", hint: "xq-motest screenshot /tmp/screen.png", command: "screenshot")
    }
}

struct Launch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Launch app by bundle id")

    @OptionGroup var globals: GlobalOptions
    @Argument(help: "Bundle identifier")
    var bundleID: String

    mutating func run() async throws {
        let config = globals.makeConfig()
        let transport = WSJSONRPCTransport(config: config)
        do {
            try await CommandRunner.launch(config: config, transport: transport, bundleID: bundleID)
            Envelope.emit(nil, pretty: config.pretty, tier: .action)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct Foreground: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Bring foreground app to front")

    @OptionGroup var globals: GlobalOptions

    mutating func run() async throws {
        let config = globals.makeConfig()
        let transport = WSJSONRPCTransport(config: config)
        do {
            try await KitCall.action(
                config: config,
                transport: transport,
                method: "device.apps.foreground",
                params: .object([:])
            )
            Envelope.emit(nil, pretty: config.pretty, tier: .action)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct Dump: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Raw device.dump.ui result")

    @OptionGroup var globals: GlobalOptions

    mutating func run() async throws {
        let config = globals.makeConfig()
        let transport = WSJSONRPCTransport(config: config)
        do {
            let envelope = try await CommandRunner.dump(config: config, transport: transport)
            Envelope.emit(envelope, pretty: config.pretty, tier: .data)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct Rpc: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Raw JSON-RPC escape hatch")

    @OptionGroup var globals: GlobalOptions
    @Argument(help: "DeviceKit method name")
    var method: String?
    @Argument(help: "JSON params string")
    var params: String?

    mutating func run() async throws {
        let config = globals.makeConfig()
        let transport = WSJSONRPCTransport(config: config)
        do {
            let envelope = try await CommandRunner.rpc(
                config: config,
                transport: transport,
                method: method,
                paramsJSON: params
            )
            Envelope.emit(envelope, pretty: config.pretty, tier: .data)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct DeviceKitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devicekit",
        abstract: "DeviceKit agent lifecycle",
        subcommands: [InstallCommand.self, StartCommand.self, StatusCommand.self]
    )
}

struct InstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Install DeviceKit runner")

    @OptionGroup var globals: GlobalOptions
    @Flag(name: .long, help: "Install on booted simulator")
    var sim = false
    @Option(name: .long, help: "Device UDID")
    var device: String?
    @Option(name: .long, help: "Provisioning profile for real device")
    var provisioningProfile: String?
    @Option(name: .long, help: "Codesign identity override")
    var signingIdentity: String?
    @Flag(name: .long, help: "Force reinstall")
    var force = false
    @Option(name: .long, help: "Pinned release version")
    var version: String?
    @Option(name: .long, help: "Local unsigned IPA path")
    var ipa: String?

    mutating func run() throws {
        let config = globals.makeConfig()
        do {
            if sim {
                guard let udid = device ?? config.deviceID ?? ProcessInfo.processInfo.environment["XQ_MOTEST_DEVICE"] else {
                    throw CLIError.usage(
                        "devicekit install --sim requires booted simulator UDID via --device",
                        hint: "xq-motest devicekit install --sim --device <UDID>"
                    )
                }
                try AgentLifecycle.installSim(
                    config: config,
                    udid: udid,
                    version: version ?? "0.0.20",
                    force: force
                )
            } else {
                guard let udid = device else {
                    throw CLIError.usage(
                        "devicekit install requires --sim or --device UDID",
                        hint: "xq-motest devicekit install --sim"
                    )
                }
                guard let provisioningProfile else {
                    throw CLIError.usage(
                        "Missing provisioning profile for device install",
                        hint: "xq-motest devicekit install --device UDID --provisioning-profile PATH"
                    )
                }
                try AgentLifecycle.installDevice(
                    config: config,
                    udid: udid,
                    provisioningProfile: provisioningProfile,
                    signingIdentity: signingIdentity,
                    version: version ?? "0.0.20",
                    ipaPath: ipa
                )
            }
            Envelope.emit(nil, pretty: config.pretty, tier: .action)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct StartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "start", abstract: "Start DeviceKit runner")

    @OptionGroup var globals: GlobalOptions
    @Flag(name: .long, help: "Start on simulator")
    var sim = false
    @Option(name: .long, help: "Device UDID")
    var device: String?

    mutating func run() throws {
        let config = globals.makeConfig()
        do {
            try AgentLifecycle.start(config: config, sim: sim, deviceID: device)
            Envelope.emit(nil, pretty: config.pretty, tier: .action)
        } catch let error as CLIError {
            Envelope.emitFailure(error, pretty: config.pretty)
        }
    }
}

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status", abstract: "DeviceKit install/runtime status")

    @OptionGroup var globals: GlobalOptions
    @Option(name: .long, help: "Device UDID")
    var device: String?

    mutating func run() throws {
        let config = globals.makeConfig()
        let status = AgentLifecycle.status(config: config, device: device)
        let result: JSONValue = .object([
            "installed": .bool(status.installed),
            "bundle_id": status.bundleID.map(JSONValue.string) ?? .null,
            "version": status.version.map(JSONValue.string) ?? .null,
            "server_reachable": .bool(status.serverReachable),
            "base_url": .string(status.baseURL),
            "device_id": status.deviceID.map(JSONValue.string) ?? .null,
            "mode": status.mode.map(JSONValue.string) ?? .null,
        ])
        let envelope = Envelope.success(
            command: "devicekit.status",
            result: result,
            baseURL: config.baseURL
        )
        Envelope.emit(envelope, pretty: config.pretty, tier: .data)
    }
}

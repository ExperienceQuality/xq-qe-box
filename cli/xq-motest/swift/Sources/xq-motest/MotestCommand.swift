import ArgumentParser
import Foundation
import Motest

struct GlobalOptions: ParsableArguments {
    @Option(name: .long, help: "DeviceKit HTTP base URL")
    var baseURL: String?

    @Option(name: .long, help: "Timeout in seconds for RPC, health, and ensure")
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
        do {
            let envelope = try await CommandRunner.health(
                config: config,
                transport: WSJSONRPCTransport(config: config)
            )
            CLIEmit.emit(envelope, pretty: config.pretty, tier: .data)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "health")
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
        do {
            let envelope = try await CommandRunner.map(
                config: config,
                transport: WSJSONRPCTransport(config: config),
                includeRaw: includeRaw
            )
            CLIEmit.emit(envelope, pretty: config.pretty, tier: .data)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "map")
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
            CLIEmit.emit(envelope, pretty: config.pretty, tier: .data)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "diff.map")
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
        do {
            try await CommandRunner.tap(
                config: config,
                transport: WSJSONRPCTransport(config: config),
                first: first,
                second: second,
                ref: ref,
                x: x,
                y: y
            )
            CLIEmit.emit(nil, pretty: config.pretty, tier: .action)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "tap")
        }
    }
}

struct TypeText: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "type",
        abstract: "Type text, optionally after tapping @eN"
    )
    @OptionGroup var globals: GlobalOptions
    @Argument(help: "@eN or text")
    var first: String
    @Argument(parsing: .remaining, help: "Text when first arg is a ref")
    var rest: [String] = []
    @Option(name: .long, help: "Element ref")
    var ref: String?

    mutating func run() async throws {
        let config = globals.makeConfig()
        do {
            try await CommandRunner.type(
                config: config,
                transport: WSJSONRPCTransport(config: config),
                first: first,
                rest: rest,
                ref: ref
            )
            CLIEmit.emit(nil, pretty: config.pretty, tier: .action)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "type")
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
        do {
            try await CommandRunner.screenshot(
                config: config,
                transport: WSJSONRPCTransport(config: config),
                path: path
            )
            CLIEmit.emit(nil, pretty: config.pretty, tier: .action)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "screenshot")
        }
    }
}

struct Launch: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Launch app by bundle id")
    @OptionGroup var globals: GlobalOptions
    @Argument(help: "Bundle identifier")
    var bundleID: String

    mutating func run() async throws {
        let config = globals.makeConfig()
        do {
            try await CommandRunner.launch(
                config: config,
                transport: WSJSONRPCTransport(config: config),
                bundleID: bundleID
            )
            CLIEmit.emit(nil, pretty: config.pretty, tier: .action)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "launch")
        }
    }
}

struct Foreground: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Bring foreground app to front")
    @OptionGroup var globals: GlobalOptions

    mutating func run() async throws {
        let config = globals.makeConfig()
        do {
            try await CommandRunner.foreground(
                config: config,
                transport: WSJSONRPCTransport(config: config)
            )
            CLIEmit.emit(nil, pretty: config.pretty, tier: .action)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "foreground")
        }
    }
}

struct Dump: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Raw device.dump.ui result")
    @OptionGroup var globals: GlobalOptions

    mutating func run() async throws {
        let config = globals.makeConfig()
        do {
            let envelope = try await CommandRunner.dump(
                config: config,
                transport: WSJSONRPCTransport(config: config)
            )
            CLIEmit.emit(envelope, pretty: config.pretty, tier: .data)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "dump")
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
        do {
            let envelope = try await CommandRunner.rpc(
                config: config,
                transport: WSJSONRPCTransport(config: config),
                method: method,
                paramsJSON: params
            )
            CLIEmit.emit(envelope, pretty: config.pretty, tier: .data)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "rpc")
        }
    }
}

struct DeviceKitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devicekit",
        abstract: "DeviceKit runtime (assumes runner preinstalled by infra)",
        subcommands: [StartCommand.self, StatusCommand.self]
    )
}

struct StartCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start an already-installed DeviceKit runner"
    )
    @OptionGroup var globals: GlobalOptions
    @Flag(name: .long, help: "Start on simulator")
    var sim = false
    @Option(name: .long, help: "Device UDID")
    var device: String?

    mutating func run() async throws {
        let config = globals.makeConfig()
        do {
            try await CommandRunner.devicekitStart(config: config, sim: sim, deviceID: device)
            CLIEmit.emit(nil, pretty: config.pretty, tier: .action)
        } catch {
            CLIEmit.emitFailure(error, pretty: config.pretty, command: "devicekit.start")
        }
    }
}

struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "DeviceKit runtime status"
    )
    @OptionGroup var globals: GlobalOptions
    @Option(name: .long, help: "Device UDID")
    var device: String?

    mutating func run() async throws {
        let config = globals.makeConfig()
        let envelope = await CommandRunner.devicekitStatus(config: config, device: device)
        CLIEmit.emit(envelope, pretty: config.pretty, tier: .data)
    }
}

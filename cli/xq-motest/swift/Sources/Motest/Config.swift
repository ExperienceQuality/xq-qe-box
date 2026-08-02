import Foundation

public struct Config: Sendable {
    public var baseURL: String
    public var timeoutSec: TimeInterval
    public var pretty: Bool
    public var ensureRuntime: Bool
    public var stateDir: URL
    public var deviceID: String?
    /// Directory with build-for-testing products (`.xctestrun` + `Release-iphoneos/`).
    /// Required for real-device `devicekit start` (Apple-only path). Env: `XQ_MOTEST_DEVICEKIT_PRODUCTS`.
    public var productsDir: URL?

    public init(
        baseURL: String = "http://127.0.0.1:12004",
        timeoutSec: TimeInterval = 30,
        pretty: Bool = false,
        ensureRuntime: Bool = true,
        stateDir: URL? = nil,
        deviceID: String? = nil,
        productsDir: URL? = nil
    ) {
        self.baseURL = baseURL
        self.timeoutSec = timeoutSec
        self.pretty = pretty
        self.ensureRuntime = ensureRuntime
        self.stateDir = stateDir ?? Config.defaultStateDir()
        self.deviceID = deviceID
        self.productsDir = productsDir
    }

    public static func defaultStateDir() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".xq-motest", isDirectory: true)
    }

    public static func fromEnvironment(
        baseURL: String? = nil,
        timeoutSec: TimeInterval? = nil,
        pretty: Bool = false,
        ensureRuntime: Bool = true,
        stateDir: URL? = nil,
        deviceID: String? = nil,
        productsDir: URL? = nil
    ) -> Config {
        let env = ProcessInfo.processInfo.environment
        let products = productsDir ?? env["XQ_MOTEST_DEVICEKIT_PRODUCTS"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
        return Config(
            baseURL: baseURL ?? env["XQ_MOTEST_BASE_URL"] ?? "http://127.0.0.1:12004",
            timeoutSec: timeoutSec ?? TimeInterval(env["XQ_MOTEST_TIMEOUT"] ?? "") ?? 30,
            pretty: pretty,
            ensureRuntime: ensureRuntime,
            stateDir: stateDir ?? env["XQ_MOTEST_STATE_DIR"].map {
                URL(fileURLWithPath: $0, isDirectory: true)
            },
            deviceID: deviceID ?? env["XQ_MOTEST_DEVICE"],
            productsDir: products
        )
    }

    public func wsURL() -> URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/ws"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    public func healthURL() -> URL? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        var path = components.path
        if !path.hasSuffix("/") { path += "/" }
        path += "health"
        components.path = path
        return components.url
    }

    public func listenPort() -> Int {
        if let url = URL(string: baseURL), let port = url.port {
            return port
        }
        return 12_004
    }
}

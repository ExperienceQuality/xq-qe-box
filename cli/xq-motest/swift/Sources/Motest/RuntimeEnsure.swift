import Foundation

public enum RuntimeEnsure {
    /// When `config.ensureRuntime` is true, ensure DeviceKit responds on `/health` before RPC.
    /// Starts the installed runner via `devicekit start` when the server is down.
    public static func ensure(config: Config) throws {
        guard config.ensureRuntime else { return }
        if AgentLifecycle.isServerReachable(config: config) { return }

        let status = AgentLifecycle.status(config: config, device: config.deviceID)
        guard status.installed else {
            throw CLIError.runtime(
                "DeviceKit runner not installed",
                hint: installHint(mode: status.mode)
            )
        }

        let sim = status.mode != "device"
        try AgentLifecycle.start(
            config: config,
            sim: sim,
            deviceID: config.deviceID ?? status.deviceID
        )
        try HealthWait.poll(port: config.listenPort(), timeoutSec: config.timeoutSec)
    }

    private static func installHint(mode: String?) -> String {
        if mode == "device" {
            return "xq-motest devicekit install --device UDID --provisioning-profile PATH"
        }
        return "xq-motest devicekit install --sim --device <UDID>"
    }
}

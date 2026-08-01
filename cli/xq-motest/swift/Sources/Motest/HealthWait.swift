import Foundation

enum HealthWait {
    static func poll(port: Int, timeoutSec: TimeInterval, logHint: String? = nil) throws {
        guard let url = URL(string: "http://127.0.0.1:\(port)/health") else {
            throw CLIError.runtime("invalid health URL", hint: "")
        }
        let deadline = Date().addingTimeInterval(timeoutSec)
        var lastError = ""
        while Date() < deadline {
            var request = URLRequest(url: url)
            request.timeoutInterval = 2
            let semaphore = DispatchSemaphore(value: 0)
            var ok = false
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    ok = true
                } else if let error {
                    lastError = error.localizedDescription
                } else if let http = response as? HTTPURLResponse {
                    lastError = "HTTP \(http.statusCode)"
                }
                semaphore.signal()
            }.resume()
            _ = semaphore.wait(timeout: .now() + 3)
            if ok { return }
            Thread.sleep(forTimeInterval: 1)
        }
        var message = "DeviceKit health check timed out"
        if let logHint { message += ". See \(logHint)" }
        if !lastError.isEmpty { message += " (last error: \(lastError))" }
        throw CLIError.runtime(message, hint: "xq-motest devicekit start --sim")
    }
}

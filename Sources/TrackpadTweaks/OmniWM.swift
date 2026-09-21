import Foundation

private let omniWMDebug = ProcessInfo.processInfo.environment["TRACKPAD_TWEAKS_DEBUG"] != nil
private func odbg(_ s: @autoclosure () -> String) {
    if omniWMDebug { FileHandle.standardError.write(Data("[tweaks] \(s())\n".utf8)) }
}

/// Drives OmniWM directly over its IPC channel instead of synthesizing keys.
/// OmniWM ignores synthetic key events for its hotkeys (they fall through to
/// the focused app — the "pong" beep), so `omniwmctl` is the reliable path.
///
/// Requires the IPC server to be enabled in OmniWM Settings. If it isn't,
/// every call fails fast with a debug log and the gesture becomes a no-op.
enum OmniWM {
    static func switchWorkspace(next: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let bin = binaryURL() else {
                odbg("omniwmctl not found — skipping workspace switch")
                return
            }
            let proc = Process()
            proc.executableURL = bin
            proc.arguments = ["command", "switch-workspace", next ? "next" : "prev"]
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            do {
                try proc.run()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 {
                    odbg("switch-workspace \(next ? "next" : "prev") ok")
                } else {
                    odbg("omniwmctl exit=\(proc.terminationStatus) — enable IPC in OmniWM Settings")
                }
            } catch {
                odbg("omniwmctl launch failed: \(error)")
            }
        }
    }

    private static var cachedBin: URL?
    private static func binaryURL() -> URL? {
        if let cached = cachedBin { return cached }
        for path in [
            "/opt/homebrew/bin/omniwmctl",
            "/usr/local/bin/omniwmctl",
            "/Applications/OmniWM.app/Contents/MacOS/omniwmctl",
        ] where FileManager.default.isExecutableFile(atPath: path) {
            let url = URL(fileURLWithPath: path)
            cachedBin = url
            return url
        }
        return nil
    }
}

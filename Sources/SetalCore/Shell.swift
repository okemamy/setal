import Foundation

public struct ShellResult: Sendable {
    public let status: Int32
    public let output: String
}

public enum Shell {
    /// Une app lancée depuis le Finder n'hérite pas du PATH du terminal :
    /// on fournit explicitement les emplacements habituels des outils de dev.
    public static let searchPath: String = {
        let home = PathGuard.home
        return [
            "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin",
            "\(home)/development/flutter/bin", "\(home)/.rbenv/shims", "\(home)/.cargo/bin",
            "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        ].joined(separator: ":")
    }()

    public static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    @discardableResult
    public static func run(_ command: String) async -> ShellResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]
                var environment = ProcessInfo.processInfo.environment
                environment["PATH"] = searchPath
                process.environment = environment

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                process.standardInput = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ShellResult(status: -1, output: error.localizedDescription))
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: ShellResult(
                    status: process.terminationStatus,
                    output: String(decoding: data, as: UTF8.self)
                ))
            }
        }
    }
}

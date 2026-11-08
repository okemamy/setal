import Foundation

public struct ShellResult: Sendable {
    public let status: Int32
    public let output: String
}

public enum Shell {
    /// Une app lancée depuis le Finder n'hérite pas du PATH du terminal. On
    /// récupère celui du shell de connexion de l'utilisateur (nvm, fvm, mise,
    /// asdf…), complété par les emplacements habituels.
    public static let searchPath: String = {
        let home = PathGuard.home
        let fallback = [
            "/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin",
            "\(home)/.local/bin", "\(home)/.cargo/bin", "\(home)/go/bin", "\(home)/.bun/bin",
            "\(home)/.rbenv/shims", "\(home)/.asdf/shims", "\(home)/.local/share/mise/shims",
            "\(home)/.volta/bin", "\(home)/fvm/default/bin", "\(home)/flutter/bin",
            "\(home)/development/flutter/bin", "\(home)/.pub-cache/bin",
            "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        ]
        var seen = Set<String>()
        return (userShellPath() + fallback).filter { seen.insert($0).inserted }.joined(separator: ":")
    }()

    /// PATH du shell interactif de l'utilisateur, avec un délai maximal de 5 s.
    static func userShellPath() -> [String] {
        let marker = "__SETAL_PATH__"
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("setal-path-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil),
              let output = try? FileHandle(forWritingTo: outputURL) else { return [] }
        defer {
            try? output.close()
            try? FileManager.default.removeItem(at: outputURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-ilc", "printf '\\n\(marker)%s\\n' \"$PATH\""]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        guard (try? process.run()) != nil else { return [] }
        if done.wait(timeout: .now() + 5) == .timedOut {
            process.terminate()
            return []
        }

        let text = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? ""
        guard let line = text.split(separator: "\n").last(where: { $0.hasPrefix(marker) }) else { return [] }
        return line.dropFirst(marker.count).split(separator: ":").map(String.init).filter { !$0.isEmpty }
    }

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

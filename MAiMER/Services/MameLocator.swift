//
//  MameLocator.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

actor MameLocator {
    private let customPathKey = "customMameExecutablePath"

    /// Standard macOS search paths for MAME binary
    private var standardCandidatePaths: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/opt/homebrew/bin/mame",                  // Apple Silicon Homebrew
            "/usr/local/bin/mame",                     // Intel Homebrew
            "/opt/local/bin/mame",                     // MacPorts
            "\(home)/bin/mame",                        // User local bin
            "\(home)/.local/bin/mame",                 // User .local bin
            "/Applications/mame/mame",                 // Applications folder
            "\(home)/Applications/mame/mame"           // User Applications folder
        ]
    }

    /// Attempts to find a working MAME binary on the system.
    func findMame() async -> MameInfo? {
        // 1. Check custom path saved in user defaults
        if let customPath = UserDefaults.standard.string(forKey: customPathKey), !customPath.isEmpty {
            let url = URL(fileURLWithPath: customPath)
            if let info = await validate(at: url) {
                return info
            }
        }

        // 2. Check standard candidate file system locations
        for path in standardCandidatePaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.isExecutableFile(atPath: url.path) {
                if let info = await validate(at: url) {
                    return info
                }
            }
        }

        // 3. Fallback: query user's login shell via `which mame`
        if let whichPath = await resolveViaShell(), !whichPath.isEmpty {
            let url = URL(fileURLWithPath: whichPath)
            if let info = await validate(at: url) {
                return info
            }
        }

        return nil
    }

    /// Validates an executable at the given URL by running `mame -version`.
    func validate(at url: URL) async -> MameInfo? {
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            return nil
        }

        do {
            let (output, exitCode) = try await runProcess(executableURL: url, arguments: ["-version"])
            guard exitCode == 0 else { return nil }

            let version = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !version.isEmpty else { return nil }

            return MameInfo(executableURL: url, version: version)
        } catch {
            return nil
        }
    }

    /// Saves a user-selected custom MAME binary path.
    func setCustomMamePath(_ path: String?) {
        if let path, !path.isEmpty {
            UserDefaults.standard.set(path, forKey: customPathKey)
        } else {
            UserDefaults.standard.removeObject(forKey: customPathKey)
        }
    }

    // MARK: - Private Helpers

    private func resolveViaShell() async -> String? {
        do {
            let zshURL = URL(fileURLWithPath: "/bin/zsh")
            let (output, exitCode) = try await runProcess(
                executableURL: zshURL,
                arguments: ["-l", "-c", "which mame"]
            )
            guard exitCode == 0 else { return nil }
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        } catch {
            return nil
        }
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String]
    ) async throws -> (output: String, exitCode: Int32) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: (output, process.terminationStatus))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

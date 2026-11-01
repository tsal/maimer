//
//  MameDataService.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

actor MameDataService {
    /// Fetches MAME XML metadata for a list of set names (e.g. ["pacman", "dkong"]).
    /// Queries MAME in batches to balance speed, memory, and responsiveness.
    func fetchMetadata(
        for setNames: [String],
        mameExecutableURL: URL,
        batchSize: Int = 30,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> [String: Game] {
        guard !setNames.isEmpty else { return [:] }

        var results: [String: Game] = [:]
        let total = setNames.count
        var processed = 0

        let chunks = stride(from: 0, to: setNames.count, by: batchSize).map {
            Array(setNames[$0..<min($0 + batchSize, setNames.count)])
        }

        for chunk in chunks {
            var arguments = ["-listxml"]
            arguments.append(contentsOf: chunk)

            let (outputData, exitCode) = try await runProcess(
                executableURL: mameExecutableURL,
                arguments: arguments
            )

            if exitCode == 0, !outputData.isEmpty {
                let parser = MameXmlParser()
                let parsed = parser.parse(data: outputData)
                results.merge(parsed) { _, new in new }
            }

            processed += chunk.count
            onProgress?(min(processed, total), total)
        }

        return results
    }

    /// Fetches MAME XML metadata for a single set name.
    func fetchSingleGame(
        setName: String,
        mameExecutableURL: URL
    ) async throws -> Game? {
        let results = try await fetchMetadata(
            for: [setName],
            mameExecutableURL: mameExecutableURL,
            batchSize: 1
        )
        return results[setName.lowercased()]
    }

    // MARK: - Private Process Runner

    private func runProcess(
        executableURL: URL,
        arguments: [String]
    ) async throws -> (data: Data, exitCode: Int32) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe() // discard stderr

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: (data, process.terminationStatus))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

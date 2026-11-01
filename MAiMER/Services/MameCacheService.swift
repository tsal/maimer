//
//  MameCacheService.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

nonisolated struct MameCache: Codable, Sendable {
    var mameVersion: String
    var lastUpdated: Date
    var games: [String: Game]
    var favorites: Set<String>

    init(
        mameVersion: String = "",
        lastUpdated: Date = Date(),
        games: [String: Game] = [:],
        favorites: Set<String> = []
    ) {
        self.mameVersion = mameVersion
        self.lastUpdated = lastUpdated
        self.games = games
        self.favorites = favorites
    }
}

actor MameCacheService {
    private let fileManager = FileManager.default

    private var cacheDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MAiMER", isDirectory: true)
    }

    var cacheFileURL: URL {
        cacheDirectoryURL.appendingPathComponent("mame_cache.json")
    }

    /// Loads the cache from Application Support.
    func load() -> MameCache? {
        guard fileManager.fileExists(atPath: cacheFileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            return try decoder.decode(MameCache.self, from: data)
        } catch {
            print("Failed to load MAME cache: \(error)")
            return nil
        }
    }

    /// Persists the cache to Application Support using PropertyListEncoder.
    func save(_ cache: MameCache) throws {
        if !fileManager.fileExists(atPath: cacheDirectoryURL.path) {
            try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(cache)
        try data.write(to: cacheFileURL, options: .atomic)
    }

    /// Clears the cache file.
    func clear() throws {
        if fileManager.fileExists(atPath: cacheFileURL.path) {
            try fileManager.removeItem(at: cacheFileURL)
        }
    }

    /// Returns human-readable cache file size, or "0 B" if not present.
    func formattedFileSize() -> String {
        guard let attrs = try? fileManager.attributesOfItem(atPath: cacheFileURL.path),
              let size = attrs[.size] as? Int64 else {
            return "0 B"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

//
//  GameIndex.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

struct GameIndex {
    var games: [Game]
    var favorites: Set<String>
    var availableGames: [Int]
    var missingGames: [Int]
    var favoriteGames: [Int]
    var parentGames: [Int]
    var cloneGames: [Int]
    var workingGames: [Int]
    var chdGames: [Int]
    var searchCache: [String: [Int]]
    var maxCacheSize: Int

    init(
        games: [Game] = [],
        favorites: Set<String> = [],
        availableGames: [Int] = [],
        missingGames: [Int] = [],
        favoriteGames: [Int] = [],
        parentGames: [Int] = [],
        cloneGames: [Int] = [],
        workingGames: [Int] = [],
        chdGames: [Int] = [],
        searchCache: [String: [Int]] = [:],
        maxCacheSize: Int = 100
    ) {
        self.games = games
        self.favorites = favorites
        self.availableGames = availableGames
        self.missingGames = missingGames
        self.favoriteGames = favoriteGames
        self.parentGames = parentGames
        self.cloneGames = cloneGames
        self.workingGames = workingGames
        self.chdGames = chdGames
        self.searchCache = searchCache
        self.maxCacheSize = maxCacheSize
    }

    // MARK: - Factory / Builder

    static func build(
        games: [Game],
        favorites: Set<String> = [],
        maxCacheSize: Int = 100
    ) -> GameIndex {
        var index = GameIndex(
            games: games,
            favorites: favorites,
            maxCacheSize: maxCacheSize
        )
        index.buildIndices()
        return index
    }

    // MARK: - Index Building

    mutating func buildIndices() {
        availableGames.removeAll()
        missingGames.removeAll()
        favoriteGames.removeAll()
        parentGames.removeAll()
        cloneGames.removeAll()
        workingGames.removeAll()
        chdGames.removeAll()

        for (i, game) in games.enumerated() {
            // Available games
            if game.status == .available {
                availableGames.append(i)
            }

            // Missing games
            if game.status == .missing {
                missingGames.append(i)
            }

            // Favorite games
            if favorites.contains(game.name) {
                favoriteGames.append(i)
            }

            // Parent games (non-clones)
            if !game.isClone {
                parentGames.append(i)
            } else {
                cloneGames.append(i)
            }

            // Working games
            if game.driverStatus == "good" {
                workingGames.append(i)
            }

            // CHD games
            if game.requiresChd {
                chdGames.append(i)
            }
        }
    }

    // MARK: - Clones

    func hasClones(for gameName: String) -> Bool {
        games.contains { $0.parent == gameName }
    }

    func hasClones(_ gameName: String) -> Bool {
        hasClones(for: gameName)
    }

    func clones(for gameName: String) -> [Int] {
        games.indices.filter { games[$0].parent == gameName }
    }

    func getClones(for gameName: String) -> [Int] {
        clones(for: gameName)
    }

    func getClones(_ gameName: String) -> [Int] {
        clones(for: gameName)
    }

    // MARK: - Search Cache

    func cachedSearch(for searchText: String) -> [Int]? {
        searchCache[searchText]
    }

    func getCachedSearch(for searchText: String) -> [Int]? {
        cachedSearch(for: searchText)
    }

    func getCachedSearch(_ searchText: String) -> [Int]? {
        cachedSearch(for: searchText)
    }

    mutating func cacheSearch(_ searchText: String, results: [Int]) {
        if searchCache.count >= maxCacheSize {
            // Remove oldest entry
            if let oldestKey = searchCache.keys.first {
                searchCache.removeValue(forKey: oldestKey)
            }
        }
        searchCache[searchText] = results
    }

    mutating func cacheSearch(for searchText: String, results: [Int]) {
        cacheSearch(searchText, results: results)
    }

    mutating func clearCache() {
        searchCache.removeAll()
    }

    // MARK: - Sorting

    func sortedIndices(by column: String = "name", ascending: Bool = true) -> [Int]? {
        let sorted = games.indices.sorted { a, b in
            if ascending {
                return games[a].name < games[b].name
            } else {
                return games[a].name > games[b].name
            }
        }
        return Array(sorted)
    }

    func getSorted(column: String = "name", ascending: Bool = true) -> [Int]? {
        sortedIndices(by: column, ascending: ascending)
    }

    func getSorted(_ column: String, _ ascending: Bool) -> [Int]? {
        sortedIndices(by: column, ascending: ascending)
    }

    // MARK: - Favorites

    mutating func updateFavorites(_ favorites: Set<String>) {
        self.favorites = favorites
        favoriteGames = games.indices.filter { favorites.contains(games[$0].name) }
    }

    mutating func updateFavorites(_ games: [Game], favorites: Set<String>) {
        self.games = games
        updateFavorites(favorites)
    }

    mutating func updateFavorites(games: [Game]? = nil, favorites: Set<String>) {
        if let games {
            self.games = games
        }
        updateFavorites(favorites)
    }
}

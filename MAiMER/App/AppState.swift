//
//  AppState.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation
import SwiftUI
import AppKit

@Observable
@MainActor
final class AppState {
    private let scanner = RomScanner()
    private let mameLocator = MameLocator()
    private let dataService = MameDataService()
    private let cacheService = MameCacheService()

    private let bookmarkKey = "savedRomFolderBookmark"
    private let folderPathKey = "savedRomFolderPath"
    private let fileManager = FileManager.default
    
    private var supportDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let maimerHome = appSupport.appendingPathComponent("MAiMER", isDirectory: true)
        return maimerHome.appendingPathComponent("mame", isDirectory: true)
    }
    
    var roms: [RomItem] = []
    var gamesBySetName: [String: Game] = [:]
    var gameIndex: GameIndex? = nil
    var cache: MameCache = MameCache()
    var cacheFileSize: String = "0 B"

    var selectedRomsFolderURL: URL?
    var searchText: String = ""
    var loadingStage: LoadingStage = .idle
    var progressCurrent: Int = 0
    var progressTotal: Int = 0
    var statusMessage: String = ""
    var errorMessage: String?
    var sortOrder = [KeyPathComparator(\RomItem.name)]

    // MAME detection & metadata loading state
    var mameInfo: MameInfo?
    var isDetectingMame: Bool = false
    var isLoadingMetadata: Bool = false
    var metadataProgressCurrent: Int = 0
    var metadataProgressTotal: Int = 0

    init() {
        initializeMameFolder()
        restoreRomsFolder()
        Task {
            await loadCache()
            await detectMame()
        }
    }

    var isScanning: Bool {
        loadingStage == .scanningRoms
    }

    var isBusy: Bool {
        isScanning || isLoadingMetadata
    }

    var totalBytes: Int64 {
        roms.reduce(0) { $0 + $1.fileSize }
    }

    var formattedTotalBytes: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    var filteredRoms: [RomItem] {
        let results: [RomItem]
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            results = roms
        } else {
            results = roms.filter { item in
                if item.name.lowercased().contains(query) || item.fileName.lowercased().contains(query) {
                    return true
                }
                if let game = gamesBySetName[item.name.lowercased()] {
                    return game.title.lowercased().contains(query) ||
                        game.manufacturer.lowercased().contains(query) ||
                        game.year.lowercased().contains(query) ||
                        game.driverStatus.lowercased().contains(query)
                }
                return false
            }
        }
        return results.sorted(using: sortOrder)
    }

    // MARK: - Lookups

    func findRom(bySetName name: String) -> RomItem? {
        let target = name.lowercased()
        return roms.first { $0.name.lowercased() == target }
    }

    func findClones(forParent parentName: String) -> [RomItem] {
        let target = parentName.lowercased()
        return roms.filter { item in
            if let game = gamesBySetName[item.name.lowercased()] {
                return game.isClone && game.parent?.lowercased() == target
            }
            return false
        }
    }

    // MARK: - Game Launcher

    func launchGame(_ item: RomItem) {
        guard let mameURL = mameInfo?.executableURL,
              let folderURL = selectedRomsFolderURL else { return }
            
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            Task {
                await self?.launchGameItem(item, mameURL, folderURL)
            }
        }
    }
    
    private func launchGameItem(_ item: RomItem, _ mameURL: URL, _ romPath: URL) {
        do {
            let process = Process()
            process.executableURL = mameURL
            process.arguments = [
                item.name,
                "-rompath", romPath.path,
                "-skip_gameinfo",
                "-window"
            ]
            process.currentDirectoryURL = supportDirectoryURL
            try process.run()
        } catch {
            print("Failed to launch MAME: \(error)")
        }
    }

    // MARK: - Cache Management

    func loadCache() async {
        if let loaded = await cacheService.load() {
            self.cache = loaded
            self.gamesBySetName = loaded.games
            self.gameIndex = GameIndex.build(games: Array(loaded.games.values), favorites: loaded.favorites)
            self.cacheFileSize = await cacheService.formattedFileSize()
        }
    }

    func rebuildCache() async {
        guard !roms.isEmpty else { return }
        await fetchMetadataForRoms(roms, forceRebuild: true)
    }

    func clearCache() async {
        try? await cacheService.clear()
        self.cache = MameCache()
        self.gamesBySetName.removeAll()
        self.gameIndex = GameIndex.build(games: [], favorites: [])
        self.cacheFileSize = "0 B"
        self.statusMessage = "Cache cleared"
    }

    func revealCacheInFinder() async {
        let url = await cacheService.cacheFileURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - MAME Detection

    func detectMame() async {
        isDetectingMame = true
        defer { isDetectingMame = false }
        mameInfo = await mameLocator.findMame()

        if mameInfo != nil && !roms.isEmpty {
            await fetchMetadataForRoms(roms)
        }
    }

    func setCustomMame(url: URL) async {
        isDetectingMame = true
        defer { isDetectingMame = false }
        if let info = await mameLocator.validate(at: url) {
            await mameLocator.setCustomMamePath(url.path)
            self.mameInfo = info

            if !roms.isEmpty {
                await fetchMetadataForRoms(roms)
            }
        }
    }

    // MARK: - Metadata Loading

    func fetchMetadataForRoms(_ items: [RomItem], forceRebuild: Bool = false) async {
        guard let mameURL = mameInfo?.executableURL, !items.isEmpty else { return }

        let setNamesToQuery: [String]
        if forceRebuild {
            setNamesToQuery = items.map(\.name)
            self.gamesBySetName.removeAll()
            self.cache.games.removeAll()
        } else {
            // Only query sets that are not already cached
            setNamesToQuery = items.map(\.name).filter { self.gamesBySetName[$0.lowercased()] == nil }
        }

        if setNamesToQuery.isEmpty {
            self.gameIndex = GameIndex.build(games: Array(self.gamesBySetName.values), favorites: self.cache.favorites)
            self.statusMessage = "All \(items.count) ROM sets loaded from cache"
            return
        }

        isLoadingMetadata = true
        loadingStage = .loadingMame
        metadataProgressCurrent = 0
        metadataProgressTotal = setNamesToQuery.count
        statusMessage = "Fetching MAME metadata for \(setNamesToQuery.count) new ROMs..."

        do {
            let fetchedGames = try await dataService.fetchMetadata(
                for: setNamesToQuery,
                mameExecutableURL: mameURL,
                batchSize: 30
            ) { [weak self] current, total in
                Task { @MainActor [weak self] in
                    self?.metadataProgressCurrent = current
                    self?.metadataProgressTotal = total
                    self?.statusMessage = "Fetched metadata for \(current) / \(total) games"
                }
            }

            self.gamesBySetName.merge(fetchedGames) { _, new in new }
            self.cache.games = self.gamesBySetName
            if let mameVersion = self.mameInfo?.version {
                self.cache.mameVersion = mameVersion
            }
            self.cache.lastUpdated = Date()

            try? await self.cacheService.save(self.cache)
            self.cacheFileSize = await self.cacheService.formattedFileSize()

            self.gameIndex = GameIndex.build(games: Array(self.gamesBySetName.values), favorites: self.cache.favorites)
            self.statusMessage = "Metadata ready: \(self.gamesBySetName.count) titles in library"
        } catch {
            self.errorMessage = "Failed to fetch MAME metadata: \(error.localizedDescription)"
        }

        self.isLoadingMetadata = false
        self.loadingStage = .complete
    }

    // MARK: - Actions

    func selectFolder(_ url: URL) {
        selectedRomsFolderURL = url
        saveFolderBookmark(url)
        Task {
            await scanCurrentFolder()
        }
    }

    func rescan() {
        guard selectedRomsFolderURL != nil else { return }
        Task {
            await scanCurrentFolder()
        }
    }

    func scanCurrentFolder() async {
        guard let folderURL = selectedRomsFolderURL else { return }

        loadingStage = .scanningRoms
        progressCurrent = 0
        progressTotal = 0
        errorMessage = nil
        statusMessage = "Starting scan..."

        let scanned = await scanner.scanFolder(at: folderURL) { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch message {
                case .romScanStarted:
                    self.statusMessage = "Scanning directory..."
                case .romScanProgress(let current, let total):
                    self.progressCurrent = current
                    self.progressTotal = total
                    self.statusMessage = "Scanning files: \(current) / \(total)"
                case .romScanFailed(let error):
                    self.errorMessage = error
                    self.loadingStage = .error
                default:
                    break
                }
            }
        }

        self.roms = scanned
        self.loadingStage = .complete
        self.statusMessage = "Scan complete: found \(scanned.count) ROM files"

        // Automatically fetch or populate MAME metadata if MAME is available
        if mameInfo != nil && !scanned.isEmpty {
            await fetchMetadataForRoms(scanned)
        }
    }

    // MARK: - Bookmark Persistence

    private func saveFolderBookmark(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: folderPathKey)
        if let bookmarkData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        }
    }
    
    private func initializeMameFolder() {
        if !fileManager.fileExists(atPath: supportDirectoryURL.path) {
            try! fileManager.createDirectory(at: supportDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func restoreRomsFolder() {
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
            var isStale = false
            if let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale {
                    saveFolderBookmark(resolvedURL)
                }
                self.selectedRomsFolderURL = resolvedURL
                Task {
                    await self.scanCurrentFolder()
                }
                return
            }
        }

        if let savedPath = UserDefaults.standard.string(forKey: folderPathKey) {
            let url = URL(fileURLWithPath: savedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                self.selectedRomsFolderURL = url
                Task {
                    await self.scanCurrentFolder()
                }
            }
        }
    }
}

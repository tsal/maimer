//
//  RomScanner.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

actor RomScanner {
    private let supportedExtensions: Set<String> = ["zip", "7z", "chd"]

    /// Scans the given folder URL for ROM files (.zip, .7z) and CHD images.
    /// Emits progress messages via `onProgress` and returns discovered `RomItem`s.
    func scanFolder(
        at folderURL: URL,
        onProgress: (@Sendable (LoadingMessage) -> Void)? = nil
    ) async -> [RomItem] {
        let isSecurityScoped = folderURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        onProgress?(.romScanStarted)

        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [
            .fileSizeKey,
            .contentModificationDateKey,
            .isDirectoryKey
        ]

        guard let topLevelURLs = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        ) else {
            onProgress?(.romScanFailed("Failed to read directory at \(folderURL.path)"))
            return []
        }

        // Collect all candidate file URLs (top level archives + immediate subfolder CHDs)
        var candidateURLs: [URL] = []

        for url in topLevelURLs {
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else { continue }

            if values.isDirectory == true {
                // Check immediate subfolder for CHDs (e.g. roms/kinst/kinst.chd)
                if let subURLs = try? fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: [.skipsHiddenFiles]
                ) {
                    for subURL in subURLs {
                        let ext = subURL.pathExtension.lowercased()
                        if ext == "chd" {
                            candidateURLs.append(subURL)
                        }
                    }
                }
            } else {
                let ext = url.pathExtension.lowercased()
                if supportedExtensions.contains(ext) {
                    candidateURLs.append(url)
                }
            }
        }

        let totalCandidates = candidateURLs.count
        var scannedItems: [RomItem] = []
        scannedItems.reserveCapacity(totalCandidates)

        for (index, url) in candidateURLs.enumerated() {
            let ext = url.pathExtension.lowercased()
            let rawName = url.deletingPathExtension().lastPathComponent
            let values = try? url.resourceValues(forKeys: resourceKeys)
            let size = Int64(values?.fileSize ?? 0)
            let modDate = values?.contentModificationDate ?? .distantPast

            let item = RomItem(
                id: "\(rawName).\(ext)",
                name: rawName,
                fileName: url.lastPathComponent,
                fileExtension: ext,
                fileSize: size,
                modificationDate: modDate,
                url: url
            )
            scannedItems.append(item)

            if (index + 1) % 50 == 0 || index + 1 == totalCandidates {
                onProgress?(.romScanProgress(current: index + 1, total: totalCandidates))
            }
        }

        // Sort initially by name
        scannedItems.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return scannedItems
    }
}

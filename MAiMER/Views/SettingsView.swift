//
//  SettingsView.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingClearConfirmation = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: AppSymbols.settingsGear)
                }

            cacheTab
                .tabItem {
                    Label("Cache", systemImage: AppSymbols.cache)
                }
        }
        .frame(width: 500, height: 320)
        .padding()
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("MAME Configuration") {
                LabeledContent("Status") {
                    if let mameInfo = appState.mameInfo {
                        Label("Detected (v\(mameInfo.version))", systemImage: AppSymbols.isOk)
                            .foregroundStyle(.green)
                    } else {
                        Label("Not Detected", systemImage: AppSymbols.isNotOk)
                            .foregroundStyle(.orange)
                    }
                }

                if let mameInfo = appState.mameInfo {
                    LabeledContent("Path") {
                        Text(mameInfo.path)
                            .font(.caption.monospaced())
                            .lineLimit(2)
                    }
                }
            }

            Section("ROM Library") {
                LabeledContent("Folder") {
                    if let folderURL = appState.selectedRomsFolderURL {
                        Text(folderURL.path)
                            .font(.caption.monospaced())
                            .lineLimit(2)
                    } else {
                        Text("No folder selected")
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("ROM Sets Found") {
                    Text("\(appState.roms.count) sets")
                        .monospacedDigit()
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Cache Tab

    private var cacheTab: some View {
        Form {
            Section("Local MAME Cache") {
                LabeledContent("Cached Titles") {
                    Text("\(appState.gamesBySetName.count) games")
                        .monospacedDigit()
                }

                LabeledContent("Cache File Size") {
                    Text(appState.cacheFileSize)
                        .monospacedDigit()
                }

                if !appState.cache.mameVersion.isEmpty {
                    LabeledContent("MAME Build") {
                        Text("MAME \(appState.cache.mameVersion)")
                    }
                }

                LabeledContent("Last Updated") {
                    Text(appState.cache.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Maintenance") {
                HStack(spacing: 12) {
                    Button("Rebuild Cache") {
                        Task {
                            await appState.rebuildCache()
                        }
                    }
                    .disabled(appState.roms.isEmpty || appState.isBusy)

                    Button("Clear Cache...") {
                        isShowingClearConfirmation = true
                    }
                    .disabled(appState.gamesBySetName.isEmpty && appState.cache.games.isEmpty)

                    Spacer()

                    Button("Reveal in Finder") {
                        Task {
                            await appState.revealCacheInFinder()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Clear MAME Cache?",
            isPresented: $isShowingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Cache", role: .destructive) {
                Task {
                    await appState.clearCache()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all cached game metadata from Application Support. The cache will be rebuilt the next time you scan or refresh ROMs.")
        }
    }
}

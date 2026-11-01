//
//  SettingsView.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(RomLibraryViewModel.self) private var viewModel
    @State private var isShowingClearConfirmation = false

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            cacheTab
                .tabItem {
                    Label("Cache", systemImage: "cylinder.split.1x2")
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
                    if let mameInfo = viewModel.mameInfo {
                        Label("Detected (v\(mameInfo.version))", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not Detected", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let mameInfo = viewModel.mameInfo {
                    LabeledContent("Path") {
                        Text(mameInfo.path)
                            .font(.caption.monospaced())
                            .lineLimit(2)
                    }
                }
            }

            Section("ROM Library") {
                LabeledContent("Folder") {
                    if let folderURL = viewModel.selectedFolderURL {
                        Text(folderURL.path)
                            .font(.caption.monospaced())
                            .lineLimit(2)
                    } else {
                        Text("No folder selected")
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("ROM Sets Found") {
                    Text("\(viewModel.roms.count) sets")
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
                    Text("\(viewModel.gamesBySetName.count) games")
                        .monospacedDigit()
                }

                LabeledContent("Cache File Size") {
                    Text(viewModel.cacheFileSize)
                        .monospacedDigit()
                }

                if !viewModel.cache.mameVersion.isEmpty {
                    LabeledContent("MAME Build") {
                        Text("MAME \(viewModel.cache.mameVersion)")
                    }
                }

                LabeledContent("Last Updated") {
                    Text(viewModel.cache.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Maintenance") {
                HStack(spacing: 12) {
                    Button("Rebuild Cache") {
                        Task {
                            await viewModel.rebuildCache()
                        }
                    }
                    .disabled(viewModel.roms.isEmpty || viewModel.isBusy)

                    Button("Clear Cache...") {
                        isShowingClearConfirmation = true
                    }
                    .disabled(viewModel.gamesBySetName.isEmpty && viewModel.cache.games.isEmpty)

                    Spacer()

                    Button("Reveal in Finder") {
                        Task {
                            await viewModel.revealCacheInFinder()
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
                    await viewModel.clearCache()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove all cached game metadata from Application Support. The cache will be rebuilt the next time you scan or refresh ROMs.")
        }
    }
}

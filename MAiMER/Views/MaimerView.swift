//
//  ContentView.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct MaimerView: View {
    @Environment(AppState.self) private var appState
    @State private var isShowingFolderPicker = false
    @State private var isShowingMamePicker = false
    @State private var selectedRomID: RomItem.ID?
    @State private var isInspectorPresented: Bool = true

    var body: some View {
        @Bindable var appState = appState
        NavigationStack {
            VStack(spacing: 0) {
                if appState.isBusy {
                    activeProgressBanner
                }

                if appState.selectedRomsFolderURL == nil {
                    folderEmptyState
                } else if appState.roms.isEmpty && !appState.isScanning {
                    noRomsFoundState
                } else {
                    romsTableView
                }

                Divider()
                bottomStatusBar
            }
            .navigationTitle(navigationTitle)
            .navigationSubtitle(navigationSubtitle)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    mameStatusMenu

                    Button {
                        isShowingFolderPicker = true
                    } label: {
                        Label(
                            appState.selectedRomsFolderURL == nil ? "Choose Folder" : "Change Folder",
                            systemImage: "folder"
                        )
                    }

                    Button {
                        appState.rescan()
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .disabled(appState.selectedRomsFolderURL == nil || appState.isBusy)

                    Button {
                        isInspectorPresented.toggle()
                    } label: {
                        Label("Inspector", systemImage: "sidebar.trailing")
                    }
                }
            }
            .searchable(
                text: $appState.searchText,
                prompt: "Filter \(appState.roms.count) ROM sets..."
            )
            .inspector(isPresented: $isInspectorPresented) {
                detailPane
                    .inspectorColumnWidth(min: 300, ideal: 340, max: 450)
            }
            .fileImporter(
                isPresented: $isShowingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let firstURL = urls.first {
                        appState.selectFolder(firstURL)
                    }
                case .failure(let error):
                    appState.errorMessage = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $isShowingMamePicker,
                allowedContentTypes: [.unixExecutable, .item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let firstURL = urls.first {
                        Task {
                            await appState.setCustomMame(url: firstURL)
                        }
                    }
                case .failure(let error):
                    appState.errorMessage = error.localizedDescription
                }
            }
        }
        .frame(minWidth: 850, minHeight: 480)
    }

    // MARK: - Detail Pane

    @ViewBuilder
    private var detailPane: some View {
        if let selectedID = selectedRomID,
           let item = appState.roms.first(where: { $0.id == selectedID }) {
            GameDetailView(
                romItem: item,
                game: appState.gamesBySetName[item.name.lowercased()],
                onSelectRom: { newID in
                    selectedRomID = newID
                }
            )
            .environment(appState)
        } else {
            ContentUnavailableView(
                "No Game Selected",
                systemImage: "gamecontroller",
                description: Text("Select a game from the table to view its emulation status, hardware requirements, and launch it.")
            )
        }
    }

    // MARK: - Navigation Titles

    private var navigationTitle: String {
        if let folderURL = appState.selectedRomsFolderURL {
            return folderURL.lastPathComponent
        }
        return "MAiMER"
    }

    private var navigationSubtitle: String {
        if let folderURL = appState.selectedRomsFolderURL {
            return folderURL.path
        }
        return "Select a MAME ROMs folder to begin"
    }

    // MARK: - Subviews

    @ViewBuilder
    private var mameStatusMenu: some View {
        if appState.isDetectingMame {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("Locating MAME...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let mameInfo = appState.mameInfo {
            Menu {
                Section("MAME Information") {
                    Text("Version: \(mameInfo.version)")
                    Text("Path: \(mameInfo.path)")
                }

                Divider()

                if !appState.roms.isEmpty && !appState.isBusy {
                    Button("Refresh Metadata from MAME") {
                        Task {
                            await appState.fetchMetadataForRoms(appState.roms)
                        }
                    }
                }

                Button("Choose Different MAME Binary...") {
                    isShowingMamePicker = true
                }

                Button("Re-detect MAME") {
                    Task {
                        await appState.detectMame()
                    }
                }
            } label: {
                Label("MAME \(mameInfo.displayVersion)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } else {
            Button {
                isShowingMamePicker = true
            } label: {
                Label("Locate MAME", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .help("MAME binary was not detected in standard paths. Click to choose manually.")
        }
    }

    @ViewBuilder
    private var activeProgressBanner: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text(appState.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()

                    let current = appState.isScanning ? appState.progressCurrent : appState.metadataProgressCurrent
                    let total = appState.isScanning ? appState.progressTotal : appState.metadataProgressTotal

                    if total > 0 {
                        Text("\(current) of \(total)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                let current = appState.isScanning ? appState.progressCurrent : appState.metadataProgressCurrent
                let total = appState.isScanning ? appState.progressTotal : appState.metadataProgressTotal

                if total > 0 {
                    ProgressView(
                        value: Double(current),
                        total: Double(total)
                    )
                    .progressViewStyle(.linear)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()
        }
    }

    private var folderEmptyState: some View {
        ContentUnavailableView {
            Label("No ROMs Folder Selected", systemImage: "folder.badge.gearshape")
        } description: {
            Text("Choose the folder containing your MAME ROM files (.zip, .7z) and CHD images to explore your collection.")
        } actions: {
            Button("Choose ROMs Folder...") {
                isShowingFolderPicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noRomsFoundState: some View {
        ContentUnavailableView {
            Label("No ROMs Found", systemImage: "archivebox")
        } description: {
            Text("No .zip, .7z, or .chd files were found in the selected folder.")
        } actions: {
            Button("Choose Another Folder...") {
                isShowingFolderPicker = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var romsTableView: some View {
        @Bindable var appState = appState
        Table(appState.filteredRoms, selection: $selectedRomID, sortOrder: $appState.sortOrder) {
            TableColumn("Game Title", value: \.name) { item in
                let game = appState.gamesBySetName[item.name.lowercased()]
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundStyle(game?.isClone == true ? Color.purple : Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game?.title ?? item.name)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        if game?.isClone == true, let parent = game?.parent {
                            Text("Clone of \(parent)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .width(min: 160, ideal: 240)

            TableColumn("ROM Set", value: \.name) { item in
                Text(item.name)
                    .font(.body.monospaced())
            }
            .width(min: 80, ideal: 100)

            TableColumn("Year") { item in
                let year = appState.gamesBySetName[item.name.lowercased()]?.year ?? ""
                Text(year.isEmpty ? "—" : year)
                    .foregroundStyle(.secondary)
            }
            .width(55)

            TableColumn("Manufacturer") { item in
                let mfg = appState.gamesBySetName[item.name.lowercased()]?.manufacturer ?? ""
                Text(mfg.isEmpty ? "—" : mfg)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 150)

            TableColumn("Driver") { item in
                if let driver = appState.gamesBySetName[item.name.lowercased()]?.driverStatus {
                    driverBadge(for: driver)
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                }
            }
            .width(75)

            TableColumn("Format", value: \.fileExtension) { item in
                formatBadge(for: item.fileExtension)
            }
            .width(65)

            TableColumn("Size", value: \.fileSize) { item in
                Text(item.formattedSize)
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 95)
        }
    }

    private func driverBadge(for status: String) -> some View {
        let (color, label): (Color, String) = switch status.lowercased() {
        case "good": (.green, "Good")
        case "imperfect": (.yellow, "Imperfect")
        case "preliminary": (.orange, "Prelim")
        default: (.red, status.capitalized)
        }

        return Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func formatBadge(for ext: String) -> some View {
        let color: Color = switch ext {
        case "zip": .blue
        case "7z": .purple
        case "chd": .orange
        default: .gray
        }

        return Text(ext.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var bottomStatusBar: some View {
        HStack(spacing: 16) {
            if let mameInfo = appState.mameInfo {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("MAME \(mameInfo.displayVersion)")
                        .foregroundStyle(.secondary)
                }
                .help(mameInfo.path)

                Text("•")
                    .foregroundStyle(.tertiary)
            }

            if let folderURL = appState.selectedRomsFolderURL {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(folderURL.lastPathComponent)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !appState.filteredRoms.isEmpty {
                if !appState.gamesBySetName.isEmpty {
                    Text("\(appState.gamesBySetName.count) titles identified")
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                }

                if appState.filteredRoms.count != appState.roms.count {
                    Text("Showing \(appState.filteredRoms.count) of \(appState.roms.count) sets")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(appState.roms.count) sets")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Text("•")
                    .foregroundStyle(.tertiary)

                Text(appState.formattedTotalBytes)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    MaimerView()
        .environment(AppState())
}

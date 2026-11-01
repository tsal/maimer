//
//  GameDetailView.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import SwiftUI
import AppKit

struct GameDetailView: View {
    let romItem: RomItem
    let game: Game?
    @Environment(AppState.self) private var appState
    let onSelectRom: (RomItem.ID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView
                Divider()
                actionButtons
                statusSection
                parentCloneSection
                hardwareSection
                fileDetailsSection
            }
            .padding(20)
        }
        .frame(minWidth: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(game?.isClone == true ? Color.purple.opacity(0.15) : Color.accentColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(game?.isClone == true ? Color.purple : Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(game?.title ?? romItem.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let year = game?.year, !year.isEmpty {
                        Text(year)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let mfg = game?.manufacturer, !mfg.isEmpty {
                        Text("•")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                        Text(mfg)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 6) {
                    Text(romItem.name)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    if game?.isClone == true {
                        Text("CLONE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else if game != nil {
                        Text("PARENT")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                appState.launchGame(romItem)
            } label: {
                Label("Launch Game", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.green)
            .disabled(appState.mameInfo == nil)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([romItem.url])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        GroupBox("Emulation & Status") {
            VStack(spacing: 10) {
                detailRow(label: "Driver Status") {
                    if let driver = game?.driverStatus {
                        driverBadge(for: driver)
                    } else {
                        Text("Unknown")
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                detailRow(label: "ROM Status") {
                    Text(game?.status.description ?? "Available")
                        .foregroundStyle(.secondary)
                }

                if let chdReq = game?.requiresChd, chdReq {
                    Divider()
                    detailRow(label: "CHD Requirement") {
                        HStack(spacing: 4) {
                            Image(systemName: "opticaldisc.fill")
                                .foregroundStyle(.orange)
                            Text(game?.chdName ?? "Required")
                                .font(.caption.monospaced())
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    // MARK: - Parent / Clone Section

    @ViewBuilder
    private var parentCloneSection: some View {
        if let parentName = game?.parent, game?.isClone == true {
            GroupBox("Parent Game") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This set is a clone of:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(parentName)
                            .font(.body.monospaced())
                            .fontWeight(.medium)
                    }

                    Spacer()

                    if let parentRom = appState.findRom(bySetName: parentName) {
                        Button("View Parent") {
                            onSelectRom(parentRom.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Text("Not in Library")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(8)
            }
        } else if let game, !game.isClone {
            let clones = appState.findClones(forParent: game.name)
            if !clones.isEmpty {
                GroupBox("Clones in Library (\(clones.count))") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(clones) { cloneItem in
                            HStack {
                                Text(appState.gamesBySetName[cloneItem.name.lowercased()]?.title ?? cloneItem.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Button("View") {
                                    onSelectRom(cloneItem.id)
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                            }
                            if cloneItem.id != clones.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    // MARK: - Hardware Section

    @ViewBuilder
    private var hardwareSection: some View {
        if let game {
            GroupBox("Hardware & Controls") {
                VStack(spacing: 10) {
                    if !game.controls.isEmpty {
                        detailRow(label: "Controls") {
                            Text(game.controls)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                    }

                    if !game.driver.isEmpty {
                        detailRow(label: "Driver Source") {
                            Text(game.driver)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - File Details

    private var fileDetailsSection: some View {
        GroupBox("File Details") {
            VStack(spacing: 10) {
                detailRow(label: "File Name") {
                    Text(romItem.fileName)
                        .foregroundStyle(.secondary)
                }

                Divider()

                detailRow(label: "Format") {
                    Text(romItem.fileExtension.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }

                Divider()

                detailRow(label: "Size") {
                    Text(romItem.formattedSize)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Divider()

                detailRow(label: "Modified") {
                    Text(romItem.formattedDate)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    // MARK: - Helpers

    private func detailRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            content()
        }
    }

    private func driverBadge(for status: String) -> some View {
        let (color, label): (Color, String) = switch status.lowercased() {
        case "good": (.green, "Good")
        case "imperfect": (.yellow, "Imperfect")
        case "preliminary": (.orange, "Preliminary")
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
}

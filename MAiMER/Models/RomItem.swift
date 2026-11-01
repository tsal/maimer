//
//  RomItem.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

struct RomItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let fileName: String
    let fileExtension: String
    let fileSize: Int64
    let modificationDate: Date
    let url: URL

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDate: String {
        guard modificationDate != .distantPast else { return "—" }
        return modificationDate.formatted(date: .abbreviated, time: .shortened)
    }
}

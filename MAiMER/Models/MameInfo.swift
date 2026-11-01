//
//  MameInfo.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

struct MameInfo: Equatable, Hashable, Sendable {
    let executableURL: URL
    let version: String

    var displayVersion: String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstPart = trimmed.components(separatedBy: " ").first, !firstPart.isEmpty {
            return firstPart
        }
        return trimmed
    }

    var path: String {
        executableURL.path
    }
}

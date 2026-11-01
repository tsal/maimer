//
//  LoadingMessage.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

enum LoadingMessage: Sendable {
    case mameLoadStarted
    case mameLoadProgress(String)
    case mameLoadComplete(games: [Game], warnings: [String])
    case mameLoadFailed(String)
    case romScanStarted
    case romScanProgress(current: Int, total: Int)
    case romScanComplete(games: [Game])
    case romScanFailed(String)

    // MARK: - Convenience Initializers / Factories

    static func mameLoadComplete(_ games: [Game], _ warnings: [String] = []) -> LoadingMessage {
        .mameLoadComplete(games: games, warnings: warnings)
    }

    static func romScanProgress(_ current: Int, _ total: Int) -> LoadingMessage {
        .romScanProgress(current: current, total: total)
    }

    static func romScanComplete(_ games: [Game]) -> LoadingMessage {
        .romScanComplete(games: games)
    }
}

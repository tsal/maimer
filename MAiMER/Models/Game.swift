//
//  Game.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

struct Game: Codable, Identifiable, Sendable, CustomStringConvertible {
    var id: String { name }

    let name: String
    let description: String
    let manufacturer: String
    let year: String
    let driver: String
    let driverStatus: String
    let status: RomStatus
    var parent: String?
    let category: String
    var playCount: Int
    var isClone: Bool
    let controls: String
    let requiresRoms: Bool
    let requiresChd: Bool
    let chdName: String?
    var verificationStatus: VerificationStatus?

    var title: String {
        description.isEmpty ? name : description
    }

    enum RomStatus: String, Codable, CaseIterable, CaseIterableDefaultLast {
        case available
        case missing
        case incorrect
        case notWorking
        case preliminary
        case chdRequired
        case chdMissing
        case unknown
        
        var description: String {
            switch self {
                case .available: "Available"
                case .missing: "Missing"
                case .incorrect: "Incorrect"
                case .notWorking: "Not Working"
                case .preliminary: "Preliminary"
                case .chdRequired: "CHD Required"
                case .chdMissing: "CHD Missing"
                case .unknown: "Unknown"
            }
        }
        
        init(rawString: String) {
            self = .init(rawValue: rawString) ?? .unknown
        }
    }
    
    enum VerificationStatus: String, Codable, CaseIterable, CaseIterableDefaultLast {
        case verified
        case failed
        case warning
        case notFound
        case notVerified

        init(rawString: String) {
            self = .init(rawValue: rawString) ?? .notVerified
        }
    }
}

// TODO: move these to a new home
protocol CaseIterableDefaultLast: RawRepresentable, CaseIterable {
    init(rawString: String)
}

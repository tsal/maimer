//
//  LoadingStage.swift
//  MAiMER
//
//  Created by Michael King on 11/1/26.
//

import Foundation

enum LoadingStage: String, CaseIterable, Equatable, Hashable, Sendable {
    case idle
    case loadingMame
    case scanningRoms
    case complete
    case error
}

extension LoadingStage: CustomStringConvertible {
    var description: String {
        switch self {
        case .idle:
            return "Idle"
        case .loadingMame:
            return "Loading MAME"
        case .scanningRoms:
            return "Scanning ROMs"
        case .complete:
            return "Complete"
        case .error:
            return "Error"
        }
    }
}

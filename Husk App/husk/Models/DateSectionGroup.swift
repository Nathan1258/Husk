//
//  DateSectionGroup.swift
//  husk
//
//  Created by Nathan Ellis on 31/05/2025.
//


import Foundation

enum DateSectionGroup: String, CaseIterable, Identifiable {
    case today = "Today"
    case yesterday = "Yesterday"
    case previous7Days = "Previous 7 Days"
    case previous30Days = "Previous 30 Days"
    case older = "Older"

    var id: String { self.rawValue }

    var displayOrder: Int {
        switch self {
        case .today: return 0
        case .yesterday: return 1
        case .previous7Days: return 2
        case .previous30Days: return 3
        case .older: return 4
        }
    }
}

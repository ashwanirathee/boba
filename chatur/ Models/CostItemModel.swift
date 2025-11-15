//
//  CostItemModel.swift
//  chatur
//
//  Created by ashwani on 15/08/25.
//

import Foundation

struct CostItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Double          // amount per cadence (e.g. per month / week / year)
    var cadence: Cadence
    var included: Bool = true   // include in totals
}

enum Cadence: String, CaseIterable, Codable, Identifiable {
    case monthly, weekly, yearly, daily, oneTime
    var id: String { rawValue }

//    var label: String {
//        switch self {
//        case .monthly: return "Monthly"
//        case .weekly:  return "Weekly"
//        case .yearly:  return "Yearly"
//        case .daily:   return "Daily"
//        case .oneTime: return "One-time"
//        }
//    }
    
    var label: String {
        switch self {
        case .monthly: return "M"
        case .weekly:  return "W"
        case .yearly:  return "Y"
        case .daily:   return "D"
        case .oneTime: return "OT"
        }
    }

    /// Convert this cadence to a monthly equivalent (for totals).
    var monthlyMultiplier: Double {
        switch self {
        case .monthly: return 1
        case .weekly:  return 52.0 / 12.0
        case .yearly:  return 1.0 / 12.0
        case .daily:   return 365.0 / 12.0
        case .oneTime: return 0            // not counted by default
        }
    }
}

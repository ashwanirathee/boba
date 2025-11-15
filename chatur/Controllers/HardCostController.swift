//
//  HardCostController.swift
//  chatur
//
//  Created by ashwani on 15/08/25.
//

import Foundation

final class HardCostController: ObservableObject {
    @Published var items: [CostItem] = [] {
        didSet { save() }
    }

    private let key = "hardCosts.data"

    init() { load() }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Save failed:", error)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            // starter examples
            items = [
                CostItem(name: "Rent", amount: 1195, cadence: .monthly),
                CostItem(name: "Internet", amount: 60, cadence: .monthly),
                CostItem(name: "Phone", amount: 35, cadence: .monthly)
            ]
            return
        }
        do {
            items = try JSONDecoder().decode([CostItem].self, from: data)
        } catch {
            print("Load failed:", error)
            items = []
        }
    }
}

//
//  LogStore.swift
//  chatur
//
//  Created by ashwani on 21/08/25.
//
import Foundation

final class LogStore: ObservableObject {
    @Published var lines: [String] = []
    func add(_ s: String) {
        DispatchQueue.main.async {
            let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.lines.append("[\(ts)] \(s)")
            if self.lines.count > 200 { self.lines.removeFirst(self.lines.count - 200) }
        }
    }
    func clear() { DispatchQueue.main.async { self.lines.removeAll() } }
}

//
//  WaterStore.swift
//  chatur
//
//  Created by ashwani on 22/08/25.
//


import Foundation
import SQLite3

final class WaterDataController {
    private let db = Database.shared

    // "YYYY-MM-DD"
    private func todayKey() -> String {
        let start = Calendar.current.startOfDay(for: Date())
        let c = Calendar.current.dateComponents([.year,.month,.day], from: start)
        return String(format:"%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Ensure row exists for today, return current amount.
    func amountToday() -> Int {
        let key = todayKey()

        // create if missing
        _ = db.exec("INSERT OR IGNORE INTO water(day, amount_ml) VALUES(?, 0)") { stmt in
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        }

        // fetch
        let rows = db.query("SELECT amount_ml FROM water WHERE day = ?") { stmt in
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        } map: { stmt in
            Int(sqlite3_column_int(stmt, 0))
        }
        return rows.first ?? 0
    }

    /// Apply delta (clamped to >= 0) and return new amount.
    @discardableResult
    func changeToday(by delta: Int) -> Int {
        let key = todayKey()

        // make sure row exists
        _ = db.exec("INSERT OR IGNORE INTO water(day, amount_ml) VALUES(?, 0)") { stmt in
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        }

        // clamp to >= 0 inside SQL
        _ = db.exec("""
            UPDATE water
               SET amount_ml = MAX(0, amount_ml + ?)
             WHERE day = ?;
        """) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(delta))
            sqlite3_bind_text(stmt, 2, key, -1, SQLITE_TRANSIENT)
        }

        return amountToday()
    }
}

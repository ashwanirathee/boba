import Foundation
import SQLite3

final class OutsideDataController {
    private let db = Database.shared

    private func todayKey() -> String {
        let start = Calendar.current.startOfDay(for: Date())
        let c = Calendar.current.dateComponents([.year,.month,.day], from: start)
        return String(format:"%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func minutesToday() -> Int {
        let key = todayKey()

        _ = db.exec("INSERT OR IGNORE INTO outside_time(day, minutes) VALUES(?, 0)") { stmt in
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        }

        let rows = db.query("SELECT minutes FROM outside_time WHERE day = ?") { stmt in
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        } map: { stmt in
            Int(sqlite3_column_int(stmt, 0))
        }
        return rows.first ?? 0
    }

    @discardableResult
    func changeToday(byMinutes delta: Int) -> Int {
        let key = todayKey()

        _ = db.exec("INSERT OR IGNORE INTO outside_time(day, minutes) VALUES(?, 0)") { stmt in
            sqlite3_bind_text(stmt, 1, key, -1, SQLITE_TRANSIENT)
        }

        _ = db.exec("""
            UPDATE outside_time
               SET minutes = MAX(0, minutes + ?)
             WHERE day = ?;
        """) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(delta))
            sqlite3_bind_text(stmt, 2, key, -1, SQLITE_TRANSIENT)
        }

        return minutesToday()
    }
}

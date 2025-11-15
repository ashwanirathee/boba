import Foundation
import SQLite3

final class Database {
    static let shared = Database()
    private var db: OpaquePointer?
    
    private init(){
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("database.sqlite")
        
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            fatalError("Unable to open database")
        }
        
        // Recommended PRAGMAs
        exec("PRAGMA foreign_keys = ON;")
        exec("PRAGMA journal_mode = WAL;")
        exec("PRAGMA synchronous = NORMAL;")
        exec("PRAGMA busy_timeout = 5000;")
        
        migrate()
    }
    
    deinit {
        if db != nil { sqlite3_close(db) }
    }
    
    private func migrate(){
        _ = exec("""
            CREATE TABLE IF NOT EXISTS locations(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ts REAL NOT NULL,
              lat REAL NOT NULL,
              lon REAL NOT NULL
            );
        """)
        _ = exec("""
            CREATE INDEX IF NOT EXISTS idx_ts ON locations(ts);
        """)
        _ = exec("""
            CREATE TABLE IF NOT EXISTS photos(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ts REAL NOT NULL,
              lat REAL NOT NULL,
              lon REAL NOT NULL,
              path TEXT NOT NULL UNIQUE
            );
        """)
        
        // water store
        _ = exec("""
            CREATE TABLE IF NOT EXISTS water(
              day TEXT PRIMARY KEY,          -- "YYYY-MM-DD"
              amount_ml INTEGER NOT NULL DEFAULT 0
            );
        """)
        
        // time outside
        _ = exec("""
            CREATE TABLE IF NOT EXISTS outside_time(
              day TEXT PRIMARY KEY,          -- "YYYY-MM-DD"
              minutes INTEGER NOT NULL DEFAULT 0
            );
        """)


    }
    
    @discardableResult
    func exec(_ sql: String, bind: (OpaquePointer?) -> Void = { _ in }) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        bind(stmt)
        let ok = sqlite3_step(stmt) == SQLITE_DONE
        sqlite3_finalize(stmt)
        return ok
    }
    
    func query<T>(_ sql: String,
                  bind: (OpaquePointer?) -> Void = { _ in },
                  map: (OpaquePointer?) -> T) -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        bind(stmt)
        var rows: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(map(stmt))
        }
        sqlite3_finalize(stmt)
        return rows
    }
}

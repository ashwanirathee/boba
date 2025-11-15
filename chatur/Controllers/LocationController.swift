//
//  LocationController.swift
//  chatur
//
//  Created by ashwani on 12/07/25.
//


import Foundation
import CoreLocation
import Combine
import MapKit
import SQLite3

class LocationController: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let db: Database
    
    @Published var location = Location(latitude: 0, longitude: 0)
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Published var last100Coords: [CLLocationCoordinate2D] = []

    @Published var altitudeMeters: Double? = nil // ✅ add this

    private var lastSavedAt: Date? = nil

    init(database: Database) {
        self.db = database
        super.init()
        // Load existing trail
        last100Coords = fetchLast(100)

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let coord = loc.coordinate
        altitudeMeters = loc.altitude
        location = Location(latitude: coord.latitude, longitude: coord.longitude)
        region = MKCoordinateRegion(center: coord,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))

        // Throttle saves to ~5s
        let now = Date()
        if let last = lastSavedAt, now.timeIntervalSince(last) < 5.0 {
            return
        }
        lastSavedAt = now

        // Save to DB
        insert(lat: coord.latitude, lon: coord.longitude, timestamp: now.timeIntervalSince1970)

        // Update rolling 100 samples (oldest → newest)
        last100Coords.append(coord)
        if last100Coords.count > 100 {
            last100Coords.removeFirst(last100Coords.count - 100)
        }
    }
    
    func insert(lat: Double, lon: Double, timestamp: TimeInterval) {
        db.exec("INSERT INTO locations(ts,lat,lon) VALUES(?,?,?)") { stmt in
            sqlite3_bind_double(stmt, 1, timestamp)
            sqlite3_bind_double(stmt, 2, lat)
            sqlite3_bind_double(stmt, 3, lon)
        }
    }

    func fetchLast(_ n: Int) -> [CLLocationCoordinate2D] {
        let sql = "SELECT lat, lon FROM locations ORDER BY ts DESC LIMIT \(n);"
        let results: [CLLocationCoordinate2D] = db.query(sql) { stmt in
            let lat = sqlite3_column_double(stmt, 0)
            let lon = sqlite3_column_double(stmt, 1)
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return results.reversed() // oldest→newest
    }
    
    /// ~meters per degree latitude; longitude scales by cos(latitude)
    private func bboxDeltas(latDeg: Double, radiusMeters: Double) -> (dLat: Double, dLon: Double) {
        let metersPerDegLat = 111_320.0
        let dLat = radiusMeters / metersPerDegLat
        let cosLat = max(0.00001, cos(latDeg * .pi / 180.0))
        let dLon = radiusMeters / (metersPerDegLat * cosLat)
        return (dLat, dLon)
    }

    /// Get recent photos near (lat,lon): prefilter by bounding box in SQL, then true distance in Swift.
    func fetchRecentPhotosNear(lat: Double, lon: Double, radiusMeters: Double = 3219, // ≈ 2 miles
                               candidateLimit: Int = 300, take: Int = 10) -> [PhotoRecord] {
        let (dLat, dLon) = bboxDeltas(latDeg: lat, radiusMeters: radiusMeters)
        let minLat = lat - dLat, maxLat = lat + dLat
        let minLon = lon - dLon, maxLon = lon + dLon

        // 1) Pull most recent candidates in the bounding box (fast)
        let candidates: [PhotoRecord] = db.query(
            """
            SELECT id, ts, lat, lon, path
            FROM photos
            WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?
            ORDER BY ts DESC
            LIMIT ?;
            """,
            bind: { stmt in
                sqlite3_bind_double(stmt, 1, minLat)
                sqlite3_bind_double(stmt, 2, maxLat)
                sqlite3_bind_double(stmt, 3, minLon)
                sqlite3_bind_double(stmt, 4, maxLon)
                sqlite3_bind_int(stmt, 5, Int32(candidateLimit))
            },
            map: { stmt in
                let id  = sqlite3_column_int64(stmt, 0)
                let ts  = sqlite3_column_int64(stmt, 1)
                let la  = sqlite3_column_double(stmt, 2)
                let lo  = sqlite3_column_double(stmt, 3)
                let pth = String(cString: sqlite3_column_text(stmt, 4))
                return PhotoRecord(id: id,  timestamp: ts, latitude: la, longitude: lo, filePath: pth)
            }
        )

        // 2) True distance filter + keep newest first
        let here = CLLocation(latitude: lat, longitude: lon)
        return candidates
            .filter { rec in
                let d = CLLocation(latitude: rec.latitude, longitude: rec.longitude).distance(from: here)
                return d <= radiusMeters
            }
            // already newest-first from SQL; if you want strictly last 10 newest within radius:
            .prefix(take)
            .map { $0 }
    }
    
    func migratePhotoPaths() {
        // 1. Fetch all rows (id + path)
        let rows: [(Int64, String)] = db.query("SELECT id, path FROM photos") { stmt in
            let id = sqlite3_column_int64(stmt, 0)
            let path = String(cString: sqlite3_column_text(stmt, 1))
            return (id, path)
        }
        
        // 2. Rewrite each path to just the filename
        for (id, oldPath) in rows {
            let filename = URL(fileURLWithPath: oldPath).lastPathComponent
            if filename != oldPath { // only update if it was an absolute path
                db.exec("UPDATE photos SET path = ? WHERE id = ?") { stmt in
                    sqlite3_bind_text(stmt, 1, filename, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int64(stmt, 2, id)
                }
                print("Migrated photo id=\(id): \(oldPath) → \(filename)")
            }
        }
    }

}

//
//extension LocationController {
//    func hasSameContent(as other: LocationController) -> Bool {
//        location.latitude  == other.location.latitude  &&
//        location.longitude == other.location.longitude &&
//        region.center.latitude  == other.region.center.latitude &&
//        region.center.longitude == other.region.center.longitude 
////        last100Coords == other.last100Coords
//    }
//}

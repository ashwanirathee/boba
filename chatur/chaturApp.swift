//
//  chaturApp.swift
//  chatur
//
//  Created by ashwani on 07/07/25.
//

import SwiftUI

private struct DatabaseKey: EnvironmentKey {
    static let defaultValue: Database? = nil
}

extension EnvironmentValues {
    var database: Database? {
        get { self[DatabaseKey.self] }
        set { self[DatabaseKey.self] = newValue }
    }
}


@main
struct chaturApp: App {
    let db = Database.shared
    @StateObject private var locationController = LocationController(database: Database.shared)
    
    init() {
//        locationController.migratePhotoPaths()
    }

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(locationController)
                .environment(\.database, db)
        }
    }
}

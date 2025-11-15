//
//  GeospatialScreen.swift
//  chatur
//
//  Created by ashwani on 20/08/25.
//
import SwiftUI
import ARKit

struct GeospatialScreen: View {
    @StateObject var loc = LocationController(database: .shared) // or inject
    @State private var geo = GeoStatus()
    @StateObject private var log = LogStore()
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            GeospatialView(locationController: loc, geoStatus: $geo, logStore: log)
                .ignoresSafeArea() // let ARView fill the screen
            
            VStack {
                // overlay text
                Text("Lat: \(loc.location.latitude, specifier: "%.5f")  ·  Lon: \(loc.location.longitude, specifier: "%.5f")")
                    .font(.caption2)
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding([.top, .leading], 12)
                
                Circle().fill(hudColor).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stateText(geo.state)).font(.footnote).bold()
                    Text("Accuracy: \(accuracyText(geo.accuracy))").font(.caption2)
                    ForEach(hints(for: geo.actions), id: \.self) { Text("• \($0)").font(.caption2) }
                }
                GeoLoggerHUD(log: log, geoStatus: geo)   // 👈 overlay shown ONLY here
                    .allowsHitTesting(true)
            }

        }
    }
    
    private var hudColor: Color {
        if geo.state != .localized { return .yellow }
        switch geo.accuracy {
        case .high, .medium: return .green
        case .low: return .orange
        default: return .gray
        }
    }

    private func stateText(_ s: ARGeoTrackingStatus.State) -> String {
        switch s {
        case .initializing : "initializing"
        case .localized : "localized"
        case .localizing : "localizing"
        case .notAvailable : "notAvailable"
            @unknown default : "Unknown case"}
    }
    private func accuracyText(_ a: ARGeoTrackingStatus.Accuracy) -> String {
        switch a {
        case .undetermined: "undetermined"
        case .low:     "low"
        case .medium:  "medium"
        case .high:    "high"
        @unknown default: "Unknown case" }
    }
    private func hints(for reason: ARGeoTrackingStatus.StateReason?) -> [String] {
        guard let r = reason else { return [] }
        switch r {
        case .devicePointedTooLow:         return ["Raise phone toward horizon/buildings"]
        case .worldTrackingUnstable:       return ["Move slowly, look at textured areas"]
        case .waitingForLocation:          return ["Wait for a better GPS fix"]
        case .waitingForAvailabilityCheck: return ["Checking support in this area…"]
        case .geoDataNotLoaded:            return ["Downloading localization data…"]
        case .notAvailableAtLocation:      return ["Move to a public street with landmarks"]
        case .needLocationPermissions:     return ["Enable Location permissions"]
        case .visualLocalizationFailed:    return ["Aim at distinct landmarks, avoid sky/ground"]
        case .none:                        return []
        @unknown default:                  return []
        }
    }
}

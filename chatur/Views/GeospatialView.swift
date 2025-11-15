//
//  GeospatialView.swift
//  chatur
//
//  Created by ashwani on 20/08/25.
//

import SwiftUI
import RealityKit
import ARKit

struct GeospatialView: UIViewRepresentable {
    @ObservedObject var locationController: LocationController
    @Binding var geoStatus: GeoStatus
    @ObservedObject var logStore: LogStore        // 👈 add this
    
    func makeCoordinator() -> GeospatialCoordinator {
        GeospatialCoordinator(locationController: locationController)
    }
    
    func makeUIView(context: Context) -> ARView {
        let v = ARView(frame: .zero)
        v.automaticallyConfigureSession = false
        context.coordinator.attach(v)
        v.session.delegate = context.coordinator

        context.coordinator.onStatus = { status in
            DispatchQueue.main.async { self.geoStatus = status }
        }
        context.coordinator.logSink = { line in
            self.logStore.add(line)
        }
        // ✅ USE this closure everywhere to start the session
        let runSession: (ARConfiguration) -> Void = { cfg in
            v.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
            context.coordinator.startPolling()

            // Known debug card 2 m ahead (proves rendering path)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                context.coordinator.spawnDebugBillboard()
            }
        }

        // ✅ iOS ARKit path
        if ARGeoTrackingConfiguration.isSupported {
            ARGeoTrackingConfiguration.checkAvailability { ok, _ in
                DispatchQueue.main.async {
                    if ok {
                        let cfg = ARGeoTrackingConfiguration()
//                        cfg.worldAlignment = .gravityAndHeading   // ✅ iOS-only
                        runSession(cfg)                           // ✅ CALL IT
                    } else {
                        let cfg = ARWorldTrackingConfiguration()
                        cfg.worldAlignment = .gravityAndHeading   // ✅ iOS-only
                        runSession(cfg)                           // ✅ CALL IT
                        print("Geotracking unavailable here.")
                    }
                }
            }
        } else {
            let cfg = ARWorldTrackingConfiguration()
            cfg.worldAlignment = .gravityAndHeading               // ✅ iOS-only
            runSession(cfg)                                       // ✅ CALL IT
            print("Device/iOS doesn't support ARGeoTracking.")
        }

        return v
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
//        print("update ui view")
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: GeospatialCoordinator) {
        coordinator.stopPolling()
        coordinator.arView?.session.pause()
        // If you own LocationController lifecycle here, stop it too:
        // (If LocationController is shared elsewhere, omit this.)
        // coordinator.locationController.stop()  // make this internal or add a public stop() hook
    }
    
    typealias UIViewType = ARView
}

#Preview {
    // Previews can't run ARKit, but this lets it compile.
    let db = Database.shared
    let loc = LocationController(database: db)
    let log = LogStore()

    GeospatialView(
        locationController: loc,
        geoStatus: .constant(GeoStatus()),
                             logStore: log
    )
}

//
//  GeospatialCoordinator.swift
//

import SwiftUI
import RealityKit
import ARKit
import Combine
import CoreLocation

// Assumes you already have:
/// struct GeoStatus { var state: ARGeoTrackingStatus.State = .notAvailable; var accuracy: ARGeoTrackingStatus.Accuracy = .undetermined; var actions: ARGeoTrackingStatus.StateReason = .none }
/// struct PhotoRecord { let id: String; let latitude: Double; let longitude: Double; let altitude: Double? }
// And LocationController has: location {latitude, longitude}, altitudeMeters: Double?, fetchRecentPhotosNear(...)->[PhotoRecord]

final class GeospatialCoordinator: NSObject, ARSessionDelegate {
    // Injected
    private let locationController: LocationController

    // View/session
    weak var arView: ARView?
    var onStatus: ((GeoStatus) -> Void)?
    var logSink: ((String) -> Void)?
    @inline(__always) private func L(_ s: String) { logSink?(s); print(s) }

    // Polling
    private var timerCancellable: AnyCancellable?
    private let pollEvery: TimeInterval = 10
    private let moveThresholdMeters: Double = 3

    // Geo gate
    private var geoState: ARGeoTrackingStatus.State = .notAvailable
    private var geoAccuracy: ARGeoTrackingStatus.Accuracy = .undetermined

    // Replace-all coordination
    private var isReloadingAnchors = false
    private var expectedAdds = 0
    private var receivedAdds = 0

    // Tracking sets
    private var geoAnchors: [ARGeoAnchor] = []
    private var rkAnchorsByARAnchorID: [UUID: AnchorEntity] = [:]

    private var recordByAnchorID: [UUID: PhotoRecord] = [:]

    init(locationController: LocationController) {
        self.locationController = locationController
        super.init()
        L("🧭 GeospatialCoordinator init")
    }

    deinit {
        L("🧭 deinit → stopPolling")
        stopPolling()
    }

    func attach(_ view: ARView) {
        self.arView = view
        L("🔗 attach ARView")
    }

    // MARK: Polling

    func startPolling() {
        guard timerCancellable == nil else { L("⏩ startPolling ignored (already active)"); return }
        L("⏰ startPolling every \(Int(pollEvery))s")
        timerCancellable = Timer.publish(every: pollEvery, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] tick in
                self?.L("⏱️ poll tick @ \(tick)")
                self?.poll()
            }
    }

    func stopPolling() {
        guard timerCancellable != nil else { return }
        L("⏹️ stopPolling")
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func poll() {
        guard let v = arView else { L("❌ poll: no ARView"); return }
        guard geoState == .localized else { L("🚫 poll: not localized (\(geoState))"); return }
        guard geoAccuracy == .high || geoAccuracy == .medium else { L("🚫 poll: accuracy=\(geoAccuracy)"); return }
        guard !isReloadingAnchors else { L("⏳ poll: reload in-flight, skip"); return }

        let here = CLLocationCoordinate2D(latitude: locationController.location.latitude,
                                          longitude: locationController.location.longitude)
        let alt = locationController.altitudeMeters
        L("📍 poll @ lat=\(here.latitude), lon=\(here.longitude), alt=\(alt?.description ?? "nil")")

        // Fetch data
        let records = locationController.fetchRecentPhotosNear(
            lat: here.latitude, lon: here.longitude,
            radiusMeters: 20, candidateLimit: 100, take: 10
        )
        L("🗂️ fetched \(records.count) records")

        guard !records.isEmpty else { L("🔇 no records → skip replaceAll"); return }
        replaceAllGeoAnchors(with: records)
    }

    // MARK: ARSessionDelegate

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        L("🎥 camera tracking: \(camera.trackingState)")
    }

    func session(_ session: ARSession, didChange s: ARGeoTrackingStatus) {
        geoState = s.state
        geoAccuracy = s.accuracy
        L("🌐 geo change → state=\(s.state) acc=\(s.accuracy) reason=\(s.stateReason)")
        onStatus?(GeoStatus(state: s.state, accuracy: s.accuracy, actions: s.stateReason))
        if s.state == .localized {
            L("🚀 geo localized → immediate poll")
            poll()
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let v = arView else { L("❌ didAdd: no ARView"); return }
        let geos = anchors.compactMap { $0 as? ARGeoAnchor }
        receivedAdds += geos.count
        L("✅ didAdd batch: total=\(anchors.count) geo=\(geos.count) — progress \(receivedAdds)/\(expectedAdds)")

        for geo in geos {
            let rk = AnchorEntity(anchor: geo)

            if let rec = recordByAnchorID[geo.identifier] {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let url  = docs.appendingPathComponent(rec.filePath)
                if let img = UIImage(contentsOfFile: url.path),
                   let board = makeBillboard(from: img, maxWidthMeters: 1.2) {
                    rk.addChild(board)
                    L("🖼️ attached billboard from file \(rec.filePath)")
                } else {
                    L("⚠️ Could not load image at \(url.path)")
                    // fallback so you see *something*
                    let plane = MeshResource.generatePlane(width: 1.0, height: 0.6)
                    var mat = SimpleMaterial(); mat.color = .init(tint: .red)
                    rk.addChild(ModelEntity(mesh: plane, materials: [mat]))
                }
            } else {
                L("⚠️ didAdd but no PhotoRecord for \(geo.identifier)")
            }

            v.scene.addAnchor(rk)
            rkAnchorsByARAnchorID[geo.identifier] = rk
        }


        if receivedAdds >= expectedAdds, isReloadingAnchors {
            L("🎉 reload complete — \(receivedAdds) anchors added")
            isReloadingAnchors = false
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        let geos = anchors.compactMap { $0 as? ARGeoAnchor }
        L("🗑️ didRemove total=\(anchors.count) geo=\(geos.count)")

        for geo in geos {
            // remove RK anchor if present
            if let rk = rkAnchorsByARAnchorID.removeValue(forKey: geo.identifier) {
                arView?.scene.removeAnchor(rk)
                L("🧽 removed RK anchor for \(geo.identifier)")
            }

            // drop the record mapping
            if recordByAnchorID.removeValue(forKey: geo.identifier) != nil {
                L("🧹 removed record map for \(geo.identifier)")
            }

            // prune from our local AR anchors list
            if let idx = geoAnchors.firstIndex(where: { $0.identifier == geo.identifier }) {
                geoAnchors.remove(at: idx)
                L("🧮 removed AR anchor id from tracking array")
            }
        }
        
    }

    // MARK: Replace-all with lock + dedupe

    private struct CoordKey: Hashable {
        let lat: Int, lon: Int
        init(_ c: CLLocationCoordinate2D) {
            lat = Int((c.latitude  * 1e5).rounded())   // ~1 m precision
            lon = Int((c.longitude * 1e5).rounded())
        }
    }

    private func replaceAllGeoAnchors(with records: [PhotoRecord]) {
        guard let v = arView else { L("❌ replaceAll: no ARView"); return }
        guard !isReloadingAnchors else { L("🔒 replaceAll denied (already reloading)"); return }
        isReloadingAnchors = true
        L("🔁 replaceAll start with \(records.count) records")

        // 1) Remove old (AR + RK)
        L("🧹 removing AR=\(geoAnchors.count), RK=\(rkAnchorsByARAnchorID.count)")
        for a in geoAnchors { v.session.remove(anchor: a) }
        for (_, rk) in rkAnchorsByARAnchorID { v.scene.removeAnchor(rk) }
        geoAnchors.removeAll()
        rkAnchorsByARAnchorID.removeAll()

        // 2) Deduplicate + (optionally) limit
        var set = Set<CoordKey>()
        var unique: [PhotoRecord] = []
        unique.reserveCapacity(records.count)
        for r in records {
            let key = CoordKey(.init(latitude: r.latitude, longitude: r.longitude))
            if set.insert(key).inserted { unique.append(r) }
        }
        if unique.count != records.count {
            L("🧮 deduped \(records.count) → \(unique.count)")
        }
        if unique.count > 16 {
            unique = Array(unique.prefix(16))
            L("✂️ limiting to 16 anchors for sanity while debugging")
        }

        expectedAdds = unique.count
        receivedAdds = 0
        L("➕ queue \(expectedAdds) ARGeoAnchors")

        // 3) Add new anchors on main
        DispatchQueue.main.async {
            for rec in unique {
                let coord = CLLocationCoordinate2D(latitude: rec.latitude, longitude: rec.longitude)
                if #available(iOS 18.0, *) {
                    let ar = ARGeoAnchor(coordinate: coord)
                    v.session.add(anchor: ar)
                    self.geoAnchors.append(ar)
                    self.recordByAnchorID[ar.identifier] = rec

                    self.L("📌 add ARGeoAnchor iOS18 coord=\(coord.latitude),\(coord.longitude)")
                } else {
                    let alt = self.locationController.altitudeMeters ?? 0
                    let ar = ARGeoAnchor(coordinate: coord, altitude: alt)
                    v.session.add(anchor: ar)
                    self.geoAnchors.append(ar)
                    self.recordByAnchorID[ar.identifier] = rec

                    self.L("📌 add ARGeoAnchor iOS17 coord=\(coord.latitude),\(coord.longitude) alt=\(alt)")
                }
            }

            // Grace note: if ARKit is slow to deliver didAdd, show progress
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self = self, self.isReloadingAnchors else { return }
                self.L("⌛️ didAdd pending: \(self.receivedAdds)/\(self.expectedAdds)")
            }
        }
    }

    // MARK: Billboard maker (sync, lots of logs)

    private func makeBillboard(from image: UIImage,
                               maxWidthMeters: Float = 1.2) -> Entity? {
        let w = Float(image.size.width), h = Float(image.size.height)
        guard w > 0, h > 0, let cg = image.cgImage else {
            L("⚠️ makeBillboard: bad image or no CGImage"); return nil
        }
        let width: Float = maxWidthMeters
        let height: Float = width * (h / w)
        L("🧱 billboard size \(width)m × \(height)m")

        let texOpts = TextureResource.CreateOptions(semantic: .color)
        guard let tex = try? TextureResource.generate(from: cg, options: texOpts) else {
            L("⚠️ makeBillboard: Texture.generate failed"); return nil
        }

        var mat = SimpleMaterial()
        mat.color = .init(texture: .init(tex))
        mat.metallic = .float(0)
        mat.roughness = .float(1)

        let plane = MeshResource.generatePlane(width: width, height: height)

        let front = ModelEntity(mesh: plane, materials: [mat])
        let back  = ModelEntity(mesh: plane, materials: [mat])
        back.transform.rotation = simd_quatf(angle: .pi, axis: [0, 1, 0])

        let billboard = Entity()
        billboard.addChild(front)
        billboard.addChild(back)
        billboard.components.set(BillboardComponent())
        billboard.position.y = height * 0.5

        L("✅ makeBillboard: entity ready")
        return billboard
    }

    // MARK: Debug: guaranteed visible card 2m ahead

    func spawnDebugBillboard() {
        guard let v = arView else { L("❌ spawnDebug: no ARView"); return }
        guard let cam = v.session.currentFrame?.camera else {
            L("⚠️ spawnDebug: no camera frame yet"); return
        }
        var t = matrix_identity_float4x4
        t.columns.3.z = -2.0  // 2 m forward
        let world = simd_mul(cam.transform, t)
        let anchor = AnchorEntity(world: world)

        if let img = UIImage(named: "logo"),
           let board = makeBillboard(from: img, maxWidthMeters: 1.0) {
            anchor.addChild(board)
            L("🧪 spawnDebug: used 'logo' image")
        } else {
            // fallback colored plane
            let plane = MeshResource.generatePlane(width: 1.2, height: 0.7)
            var mat = SimpleMaterial(); mat.color = .init(tint: .blue)
            anchor.addChild(ModelEntity(mesh: plane, materials: [mat]))
            L("🧪 spawnDebug: fallback blue panel")
        }

        DispatchQueue.main.async {
            v.scene.addAnchor(anchor)
            self.L("✅ spawnDebug: added anchor 2m ahead")
        }
    }
}

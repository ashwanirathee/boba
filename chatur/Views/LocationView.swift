
import SwiftUI
import MapKit

struct LocationView: View {
    @EnvironmentObject var locationController: LocationController
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)

    // Photos near me (from LocationController)
    @State private var nearbyPhotos: [PhotoRecord] = []

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 20) {
                Map(position: $camera) {
                    // Trail (last 100 points)
                    if !locationController.last100Coords.isEmpty {
                        MapPolyline(coordinates: locationController.last100Coords)
                            .stroke(.blue, lineWidth: 3)
                    }

                    // Current user dot
                    UserAnnotation()

                    // Photo pins
                    ForEach(nearbyPhotos) { rec in
                        let coord = CLLocationCoordinate2D(latitude: rec.latitude, longitude: rec.longitude)
                        Annotation(title(for: rec),
                                   coordinate: coord) {
                            VStack(spacing: 4) {
                                // Small local thumbnail if available
                                if let ui = UIImage(contentsOfFile: rec.filePath) {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 1))
                                } else {
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .padding(8)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                                }
                                Text(shortDate(rec.timestamp))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: min(geo.size.height * 0.5, 600))
                .cornerRadius(12)
                .padding()
                .mapControls { MapUserLocationButton(); MapCompass() }

                if locationController.location.isValid {
                    VStack(spacing: 8) {
                        Text("Latitude: \(String(format: "%.6f", locationController.location.latitude))")
                        Text("Longitude: \(String(format: "%.6f", locationController.location.longitude))")
                        Text("Nearby photos: \(nearbyPhotos.count)")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                } else {
                    Text("Waiting for location…").foregroundColor(.gray)
                }

                Spacer()
            }
            .padding()
            .task { refreshNearby() } // initial fetch
            .onChange(of: locationController.location.latitude) { _ in refreshNearby() }
            .onChange(of: locationController.location.longitude) { _ in refreshNearby() }
        }
    }

    private func refreshNearby(radiusMeters: Double = 3219, take: Int = 10) {
        guard locationController.location.isValid else { return }
        let lat = locationController.location.latitude
        let lon = locationController.location.longitude
        // Uses your controller’s method:
        nearbyPhotos = locationController.fetchRecentPhotosNear(
            lat: lat,
            lon: lon,
            radiusMeters: radiusMeters,
            candidateLimit: 300,
            take: take
        )
        // Optional: recenter map on current location
        camera = .userLocation(fallback: .automatic)
    }

    private func shortDate(_ ts: Int64) -> String {
        Date(timeIntervalSince1970: TimeInterval(ts)).formatted(date: .abbreviated, time: .shortened)
    }

    private func title(for rec: PhotoRecord) -> String {
        "Photo \(rec.id)"
    }
}

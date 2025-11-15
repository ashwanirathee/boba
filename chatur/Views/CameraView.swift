//
//  CameraView.swift
//  chatur
//
//  Created by ashwani on 14/08/25.
//

import SwiftUI

struct CameraView: View {
    @EnvironmentObject private var locationController: LocationController
    @Environment(\.database) private var db
    @StateObject private var cameraVM = PhotoRecordController(db: Database.shared)

    @State private var selectedEffect: PhotoEffect = .original
    private let ciContext = CIContext()
    
    var body: some View {
        ZStack {
            CameraPreview(session: cameraVM.session)
                .ignoresSafeArea()
                .photoEffectPreview(selectedEffect)

            VStack {
                // --- EFFECT PICKER ---
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PhotoEffect.allCases) { effect in
                            Text(effect.label)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(effect == selectedEffect ? Color.white.opacity(0.9) : Color.black.opacity(0.4))
                                )
                                .foregroundColor(effect == selectedEffect ? .black : .white)
                                .onTapGesture {
                                    selectedEffect = effect
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                Spacer()
                // inside VStack in CameraView, above the shutter button:

                VStack(spacing: 10) {
                    // Zoom
                    HStack {
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(.white)
                        Slider(
                            value: Binding(
                                get: { Double(cameraVM.zoomFactor) },
                                set: { cameraVM.zoomFactor = CGFloat($0) }
                            ),
                            in: 1.0...Double(max(cameraVM.maxZoomFactor, 1.0)),
                            step: 0.1
                        )
                    }

                    // Exposure compensation
                    HStack {
                        Image(systemName: "sun.min")
                            .foregroundColor(.white)
                        Slider(
                            value: Binding(
                                get: { Double(cameraVM.exposureBias) },
                                set: { cameraVM.exposureBias = Float($0) }
                            ),
                            in: Double(cameraVM.minExposureBias)...Double(cameraVM.maxExposureBias)
                        )
                    }

                    // Focus distance
                    HStack {
                        Image(systemName: "circle.dotted")
                            .foregroundColor(.white)
                        Slider(
                            value: Binding(
                                get: { Double(cameraVM.focusPosition) },
                                set: { cameraVM.focusPosition = Float($0) }
                            ),
                            in: 0.0...1.0
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.45))
                        .blur(radius: 8)
                )
                .padding(.horizontal)
                .padding(.bottom, 8)

                Button(action: {
                    cameraVM.capturePhoto()
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .overlay(Circle().stroke(Color.black, lineWidth: 2))
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            cameraVM.onPhotoCapture = { url in
                guard let db = db else { return }
                
                // 1) Apply chosen effect and get a processed file URL
                let processedURL = applyEffect(selectedEffect, toPhotoAt: url) ?? url

                let loc = locationController.location
                let record = PhotoRecord(
                    id: 0,
                    timestamp: Int64(Date().timeIntervalSince1970),
                    latitude: loc.latitude,
                    longitude: loc.longitude,
                    filePath: url.lastPathComponent
                )
                PhotoRecordController(db: db).insert(record)
            }
        }
    }
    
    /// Load image at `url`, apply CI filter, and save to a new file.
        func applyEffect(_ effect: PhotoEffect, toPhotoAt url: URL) -> URL? {
            guard effect != .original else { return url } // no-op

            guard let ciImage = CIImage(contentsOf: url),
                  let filter = effect.makeFilter(input: ciImage),
                  let outputImage = filter.outputImage
            else { return nil }

            guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
                return nil
            }

            let processed = UIImage(cgImage: cgImage)

            guard let data = processed.jpegData(compressionQuality: 0.95) else {
                return nil
            }

            // Save next to the original with a suffix, e.g. "_fx"
            let processedURL = url.deletingPathExtension()
                .appendingPathExtension("fx.jpg")

            do {
                try data.write(to: processedURL, options: .atomic)
                return processedURL
            } catch {
                print("Failed to save processed image:", error)
                return nil
            }
        }

}

#Preview {
    CameraView()
        .environmentObject(LocationController(database: Database.shared))
        .environment(\.database, Database.shared)}

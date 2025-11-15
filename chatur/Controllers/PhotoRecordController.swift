//
//  PhotoRecordController.swift
//  chatur
//
//  Created by ashwani on 14/08/25.
//

import Foundation
import SQLite3
import AVFoundation
import UIKit
import CoreLocation
import Photos
import PhotosUI

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension PhotoRecordController {
    func saveToPhotosAlbum(imageURL: URL, albumName: String = "boba") {
        // Ask only for "add" permission – matches NSPhotoLibraryAddUsageDescription
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("Photos add-only permission denied:", status.rawValue)
                return
            }

            PHPhotoLibrary.shared().performChanges({
                // 1) Create PHAsset directly from file URL
                guard let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: imageURL),
                      let assetPlaceholder = assetRequest.placeholderForCreatedAsset else {
                    return
                }
                let assets = NSArray(object: assetPlaceholder)

                // 2) Fetch existing album named `albumName`
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
                let collections = PHAssetCollection.fetchAssetCollections(
                    with: .album,
                    subtype: .any,
                    options: fetchOptions
                )

                if let existingAlbum = collections.firstObject {
                    // Add to existing album
                    if let albumChangeRequest = PHAssetCollectionChangeRequest(for: existingAlbum) {
                        albumChangeRequest.addAssets(assets)
                    }
                } else {
                    // Create a new album and add the asset to it
                    let newAlbumRequest =
                        PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                    newAlbumRequest.addAssets(assets)
                }
            }) { success, error in
                if success {
                    print("Saved photo to Photos album:", albumName)
                } else {
                    print("Error saving to Photos:", error?.localizedDescription ?? "unknown error")
                }
            }
        }
    }
}



final class PhotoRecordController:  NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    private let db: Database
    @Published var session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()

    // Keep a reference to the active video device
    private var videoDevice: AVCaptureDevice?
    
    // MARK: - Camera control state

    @Published var zoomFactor: CGFloat = 1.0 {
        didSet { setZoom(zoomFactor) }
    }

    @Published var exposureBias: Float = 0.0 {
        didSet { setExposureBias(exposureBias) }
    }

    /// 0 = near, 1 = far
    @Published var focusPosition: Float = 0.5 {
        didSet { setFocusPosition(focusPosition) }
    }

    // Exposed ranges so UI can clamp sliders correctly
    @Published var maxZoomFactor: CGFloat = 1.0
    @Published var minExposureBias: Float = 0.0
    @Published var maxExposureBias: Float = 0.0
    
    // callback when photo saved
    var onPhotoCapture: ((URL) -> Void)?
    init(db: Database) {
        self.db = db
        super.init()
        configureSession()
    }

    func insert(_ record: PhotoRecord) {
        db.exec("""
            INSERT INTO photos (ts, lat, lon, path) VALUES (?,?,?,?)
        """) { stmt in
            sqlite3_bind_int64(stmt, 1, record.timestamp)
            sqlite3_bind_double(stmt, 2, record.latitude)
            sqlite3_bind_double(stmt, 3, record.longitude)
            sqlite3_bind_text(stmt, 4, (record.filePath as NSString).utf8String, -1, SQLITE_TRANSIENT)
        }
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // 1) Create device
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .back)
        else {
            session.commitConfiguration()
            return
        }

        // 2) Create input from that device
        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output)
        else {
            session.commitConfiguration()
            return
        }

        // 3) Hook everything up
        session.addInput(input)
        session.addOutput(output)

        // 4) Now store the *same* device used by the session
        self.videoDevice = input.device

        // 5) Initialise ranges for UI from this device
        maxZoomFactor     = min(device.activeFormat.videoMaxZoomFactor, 10.0)
        minExposureBias   = device.minExposureTargetBias
        maxExposureBias   = device.maxExposureTargetBias

        // Set some neutral defaults
        zoomFactor     = 1.0
        exposureBias   = 0.0
        focusPosition  = 0.5

        session.commitConfiguration()
        session.startRunning()
    }


    // MARK: - Camera controls

    private func setZoom(_ factor: CGFloat) {
        guard let device = videoDevice else { return }
        let clamped = max(1.0, min(factor, maxZoomFactor))

        DispatchQueue.main.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                print("Zoom set:", device.videoZoomFactor, "max:", self.maxZoomFactor)
                device.unlockForConfiguration()
            } catch {
                print("Failed to set zoom:", error)
            }
        }
    }

    private func setExposureBias(_ bias: Float) {
        guard let device = videoDevice else { return }
        let clamped = max(minExposureBias, min(bias, maxExposureBias))

        DispatchQueue.main.async {
            do {
                try device.lockForConfiguration()
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.setExposureTargetBias(clamped) { value in
                    print("Exposure bias set:", value)
                }
                device.unlockForConfiguration()
            } catch {
                print("Failed to set exposure bias:", error)
            }
        }
    }

    private func setFocusPosition(_ pos: Float) {
        guard let device = videoDevice else { return }
        let clamped = max(0.0, min(pos, 1.0))

        DispatchQueue.main.async {
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.locked) {
                    device.setFocusModeLocked(lensPosition: clamped) { value in
                        print("Focus lens position set:", value)
                    }
                } else {
                    print("Locked focus not supported on this device")
                }
                device.unlockForConfiguration()
            } catch {
                print("Failed to set focus position:", error)
            }
        }
    }


    // MARK: - Capture

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        do {
            let docs = try FileManager.default.url(for: .documentDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: true)
            let filename = "IMG_\(UUID().uuidString).jpg"
            let url = docs.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            saveToPhotosAlbum(imageURL: url, albumName: "boba")
            onPhotoCapture?(url)
        } catch {
            print("Save error:", error)
        }
    }

    func documentsURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename, conformingTo: .image)
    }

}

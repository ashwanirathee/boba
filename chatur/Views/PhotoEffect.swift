import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

enum PhotoEffect: String, CaseIterable, Identifiable {
    case original
    case mono
    case sepia
    case bloom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return "Original"
        case .mono:     return "Mono"
        case .sepia:    return "Sepia"
        case .bloom:    return "Bloom"
        }
    }

    /// Build a Core Image filter for saving the photo.
    func makeFilter(input image: CIImage) -> CIFilter? {
        switch self {
        case .original:
            return nil

        case .mono:
            let filter = CIFilter.photoEffectMono()
            filter.inputImage = image
            return filter

        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.inputImage = image
            filter.intensity = 0.9
            return filter

        case .bloom:
            let filter = CIFilter.bloom()
            filter.inputImage = image
            filter.intensity = 0.8
            filter.radius = 10
            return filter
        }
    }
}

// MARK: - SwiftUI preview-style effect for live camera

extension View {
    func photoEffectPreview(_ effect: PhotoEffect) -> some View {
        switch effect {
        case .original:
            return AnyView(self)
        case .mono:
            return AnyView(
                self
                    .saturation(0.0)
            )
        case .sepia:
            return AnyView(
                self
                    .saturation(0.7)
                    .hueRotation(.degrees(25))
            )
        case .bloom:
            return AnyView(
                self
                    .saturation(1.2)
                    .brightness(0.08)
                    .blur(radius: 2)
            )
        }
    }
}

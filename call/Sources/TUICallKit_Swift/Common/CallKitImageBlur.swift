import CoreImage
import UIKit

enum CallKitImageBlur {
    static func blurred(_ image: UIImage, targetSize: CGSize, radius: Double = 26.0) -> UIImage? {
        let scale = max(targetSize.width / image.size.width, targetSize.height / image.size.height)
        let canvas = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
        let filled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: canvas))
        }
        guard let input = CIImage(image: filled) else { return nil }
        guard let blur = CIFilter(name: "CIGaussianBlur") else { return nil }
        blur.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        blur.setValue(radius, forKey: kCIInputRadiusKey)
        guard let blurred = blur.outputImage else { return nil }
        guard let saturate = CIFilter(name: "CIColorControls") else { return nil }
        saturate.setValue(blurred, forKey: kCIInputImageKey)
        saturate.setValue(1.05, forKey: kCIInputSaturationKey)
        guard let output = saturate.outputImage else { return nil }
        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: input.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

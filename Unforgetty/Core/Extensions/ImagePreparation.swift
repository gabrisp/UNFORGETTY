import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum ImagePreparation {
    // Live Activities run under a much tighter memory budget than a normal widget — a decoded
    // bitmap scales with width*height regardless of how small the on-screen frame actually is
    // (scaledToFill just crops it), so oversized source images can silently fail to render at
    // all in the real Live Activity even though they look fine in-app. Rather than hand-pick a
    // dimension/quality pair and hope it's small enough, shrink in a loop until the actual
    // encoded size is under the target — guarantees the ceiling instead of guessing at it.
    private static let targetMaxBytes = 30_000
    private static let startingMaxDimension: CGFloat = 300
    private static let maxIterations = 8

    static func preparedBackgroundImageData(from data: Data, targetMaxBytes: Int = Self.targetMaxBytes) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }

        // Cap the starting pixel dimension unconditionally — what actually stresses a Live
        // Activity's memory budget is the *decoded* bitmap (width × height × 4 bytes), not the
        // JPEG file size, so a low-detail full-resolution photo that happens to compress under
        // the byte target on the first pass would otherwise still decode at full resolution.
        var dimension = min(max(image.size.width, image.size.height), startingMaxDimension)
        var quality: CGFloat = 0.6
        var best = data

        for _ in 0..<maxIterations {
            let scale = min(1, dimension / max(image.size.width, image.size.height))
            let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
            guard let encoded = resized.jpegData(compressionQuality: quality) else { break }
            best = encoded
            if encoded.count <= targetMaxBytes { break }

            // Still too big — shrink both dimension and quality for the next pass.
            dimension *= 0.75
            quality = max(0.2, quality - 0.15)
        }
        return best
        #else
        return data
        #endif
    }

    /// A tighter re-compression pass applied only to the copy actually uploaded/downloaded for a
    /// friend ping — independent of the 30KB cap above, which is sized for the Live Activity's
    /// *local* decode-memory budget, not network/storage size. Reuses the same shrink-loop against
    /// the already-~30KB-or-smaller local copy, so this is a cheap second pass, not starting over
    /// from a full-resolution source.
    static let friendUploadTargetMaxBytes = 3_000

    static func preparedFriendUploadImageData(from data: Data) -> Data {
        preparedBackgroundImageData(from: data, targetMaxBytes: friendUploadTargetMaxBytes)
    }

    /// Two representative colors sampled from the top and bottom of the image (as hex strings, no
    /// `#`) — used to auto-derive a `.music` card's gradient from its album art. Draws into an
    /// explicit 1×2 RGBA8888 bitmap context rather than relying on a resizing renderer's default
    /// pixel format, so the byte order read back out is known for certain.
    static func gradientHexPair(from data: Data) -> (start: String, end: String)? {
        #if canImport(UIKit)
        guard let cgImage = UIImage(data: data)?.cgImage else { return nil }
        let width = 1
        let height = 2
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        func hex(row: Int) -> String {
            let offset = row * bytesPerRow
            return String(format: "%02X%02X%02X", pixelData[offset], pixelData[offset + 1], pixelData[offset + 2])
        }
        return (hex(row: 0), hex(row: 1))
        #else
        return nil
        #endif
    }
}

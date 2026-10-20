//
//  PlatformCompat.swift
//  smartbud
//
//  Small aliases so shared views compile against AppKit on macOS. Only the
//  types with a one-to-one AppKit equivalent live here; behavioural gaps
//  (haptics, screen metrics, share sheets) stay behind `#if os(macOS)` at
//  their call sites.
//

#if os(macOS)
import AppKit

typealias UIImage = NSImage
typealias UIColor = NSColor
typealias UIFont = NSFont

extension NSImage {
    /// `UIImage.pngData()` counterpart used by the OCR/export paths.
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// `UIImage.cgImage` counterpart (NSImage exposes it as a method).
    var cgImage: CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// `UIImage(systemName:)` counterpart.
    convenience init?(systemName: String) {
        self.init(systemSymbolName: systemName, accessibilityDescription: nil)
    }
}
#endif

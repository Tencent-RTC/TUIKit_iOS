//
//  GiftAnimationEngineFactory.swift
//  TUILiveKit
//
//  Factory Pattern: creates the appropriate GiftAnimationEngine based on file type.
//

import Foundation
import Metal

// MARK: - GiftAnimationFileType

enum GiftAnimationFileType {
    case svga
    case mp4
    case pag
    case unknown

    init(url: String) {
        let ext = URL(fileURLWithPath: url).pathExtension.lowercased()
        switch ext {
        case "svga":
            self = .svga
        case "mp4":
            self = .mp4
        case "pag":
            self = .pag
        default:
            self = .unknown
        }
    }
}

// MARK: - GiftAnimationEngineFactory

final class GiftAnimationEngineFactory {

    /// Create an engine for the given animation URL.
    /// - Parameter url: File path or remote URL string.
    /// - Returns: A concrete `GiftAnimationEngine`, or `nil` if the format is unsupported.
    static func createEngine(for url: String) -> GiftAnimationEngine? {
        let fileType = GiftAnimationFileType(url: url)
        switch fileType {
        case .svga:
            return SVGAAnimationEngine()
        case .mp4:
            return createMP4Engine()
        case .pag:
            return createPAGEngine()
        case .unknown:
            return nil
        }
    }

    // MARK: - Private Helpers

    private static func createMP4Engine() -> GiftAnimationEngine {
        return MP4AnimationEngine()
    }

    private static func createPAGEngine() -> GiftAnimationEngine {
        return PAGAnimationEngine()
    }
}

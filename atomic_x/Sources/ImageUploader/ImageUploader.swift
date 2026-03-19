//  Created by eddard on 2025/10/21.
//  Copyright © 2025 Tencent. All rights reserved.

import Photos
import PhotosUI
import UIKit

public struct ImageUploaderConfig {
    public enum CropOverlayShape {
        case circle
        case rectangle_1_1
        case rectangle_4_3
        case rectangle_3_4
        case rectangle_16_9
        case rectangle_9_16
    }
    
    public var showsCameraItem: Bool = false
    public var cropOverlayShape: CropOverlayShape = .circle
    
    public init(
        showsCameraItem: Bool = false,
        cropOverlayShape: CropOverlayShape = .circle
    ) {
        self.showsCameraItem = showsCameraItem
        self.cropOverlayShape = cropOverlayShape
    }
}

public protocol ImageUploaderDelegate: AnyObject {
    func imageUploaderDidCompletedPick(_ uploader: ImageUploader, localPath: String?)
    func imageUploaderDidCompletedCosUpload(_ uploader: ImageUploader, statusCode: Int)
}

public class ImageUploader {
    public weak var delegate: ImageUploaderDelegate?
    private let impl: ImageUploaderImpl
    
    public init() {
        self.impl = ImageUploaderImpl()
    }
    
    public func pick(
        from presenter: UIViewController? = nil,
        config: ImageUploaderConfig = ImageUploaderConfig(),
        cosUploadURL: String? = nil) {
        impl.pick(uploader: self, from: presenter, config: config, cosUploadURL: cosUploadURL)
    }
}

//  Created by eddard on 2025/10/21.
//  Copyright © 2025 Tencent. All rights reserved.

import UIKit
import Photos
import PhotosUI
import AtomicXCore

final class ImageUploaderImpl: NSObject {
    private let systemPhotoPickerManager = SystemPhotoPickerManager()
    private let uploadManager = ImageUploaderCosUploadManager()
    
    private var presentedViewController: UIViewController?
    private var hasStartedPicking = false
    private var imageSourceBottomSheet: ImageSourceBottomSheetView?
    private var prewarmedCameraPicker: UIImagePickerController?
    
    private var currentUploader: ImageUploader?
    private var currentConfig: ImageUploaderConfig?
    private var currentCosUploadURL: String?
    private weak var currentPresenter: UIViewController?
    
    override init() {
        super.init()
        systemPhotoPickerManager.delegate = self
    }
    
    func pick(uploader: ImageUploader, from presenter: UIViewController?,
              config: ImageUploaderConfig, cosUploadURL: String?) {
        guard let targetPresenter = presenter ?? topMostViewController() else {
            notifyCompletion(uploader: uploader, localPath: nil, statusCode: -1)
            return
        }
        startPicking(uploader: uploader, from: targetPresenter, config: config, cosUploadURL: cosUploadURL)
    }
}

private extension ImageUploaderImpl {
    func startPicking(uploader: ImageUploader, from presenter: UIViewController,
                      config: ImageUploaderConfig, cosUploadURL: String?) {
        guard !hasStartedPicking else { return }
        hasStartedPicking = true
        currentUploader = uploader
        currentPresenter = presenter
        currentConfig = config
        currentCosUploadURL = cosUploadURL
        
        if config.showsCameraItem {
            showImageSourceBottomSheet(presenter: presenter)
            prewarmCamera()
        } else {
            systemPhotoPickerManager.pickSingleImage(presenter: presenter)
        }
    }
    
    func showImageSourceBottomSheet(presenter: UIViewController) {
        let bottomSheet = ImageSourceBottomSheetView()
        bottomSheet.delegate = self
        imageSourceBottomSheet = bottomSheet
        if let window = presenter.view.window {
            bottomSheet.show(in: window)
        }
    }
    
    func hideImageSourceBottomSheet(completion: (() -> Void)? = nil) {
        imageSourceBottomSheet?.hide { [weak self] in
            self?.imageSourceBottomSheet = nil
            completion?()
        }
    }
    
    func prewarmCamera() {
        guard prewarmedCameraPicker == nil,
              UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.prewarmedCameraPicker == nil else { return }
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            self.prewarmedCameraPicker = picker
        }
    }
    
    func presentCameraPicker(presenter: UIViewController) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            if let uploader = currentUploader {
                resetPickingState()
                notifyCompletion(uploader: uploader, localPath: nil, statusCode: -1)
            }
            return
        }
        
        let cameraPicker: UIImagePickerController
        if let prewarmed = prewarmedCameraPicker {
            cameraPicker = prewarmed
            prewarmedCameraPicker = nil
        } else {
            cameraPicker = UIImagePickerController()
            cameraPicker.sourceType = .camera
        }
        
        cameraPicker.delegate = self
        cameraPicker.modalPresentationStyle = .fullScreen
        presenter.present(cameraPicker, animated: true)
        presentedViewController = cameraPicker
    }
    
    func presentCropView(with image: UIImage) {
        guard let presenter = currentPresenter, let config = currentConfig else { return }
        let cropVC = ImageUploaderCropViewController(overlayShape: config.cropOverlayShape, image: image)
        cropVC.delegate = self
        cropVC.modalPresentationStyle = .fullScreen
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        presenter.present(cropVC, animated: true)
        CATransaction.commit()
        presentedViewController = cropVC
    }
    
    func dismissPresentedVC(completion: @escaping () -> Void) {
        presentedViewController?.dismiss(animated: true) { [weak self] in
            self?.resetPickingState()
            completion()
        }
    }
    
    func resetPickingState() {
        hasStartedPicking = false
        currentUploader = nil
        presentedViewController = nil
    }
    
    func notifyCompletion(uploader: ImageUploader, localPath: String?, statusCode: Int) {
        uploader.delegate?.imageUploaderDidCompletedPick(uploader, localPath: localPath)
        uploader.delegate?.imageUploaderDidCompletedCosUpload(uploader, statusCode: statusCode)
    }
    
    func topMostViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else { return nil }
        return topMostViewController(base: rootVC)
    }
    
    func topMostViewController(base: UIViewController) -> UIViewController {
        if let nav = base as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController ?? nav)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }
        if let presented = base.presentedViewController {
            return topMostViewController(base: presented)
        }
        return base
    }
}

// MARK: - ImageSourceBottomSheetDelegate
extension ImageUploaderImpl: ImageSourceBottomSheetDelegate {
    func imageSourceBottomSheet(_ sheet: ImageSourceBottomSheetView, didSelectSource source: ImageSourceType) {
        guard let presenter = currentPresenter else { return }
        hideImageSourceBottomSheet { [weak self] in
            guard let self = self else { return }
            switch source {
            case .camera:
                self.presentCameraPicker(presenter: presenter)
            case .album:
                self.systemPhotoPickerManager.pickSingleImage(presenter: presenter)
            }
        }
    }
    
    func imageSourceBottomSheetDidCancel(_ sheet: ImageSourceBottomSheetView) {
        guard let uploader = currentUploader else { return }
        hideImageSourceBottomSheet { [weak self] in
            self?.resetPickingState()
            self?.notifyCompletion(uploader: uploader, localPath: nil, statusCode: -1)
        }
    }
}

// MARK: - UIImagePickerControllerDelegate (Camera)
extension ImageUploaderImpl: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let resultImage = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.presentedViewController = nil
            guard let uploader = currentUploader else { return }
            guard let image = resultImage else {
                resetPickingState()
                notifyCompletion(uploader: uploader, localPath: nil, statusCode: -1)
                return
            }
            
            self.presentCropView(with: image)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        guard let uploader = currentUploader else { return }
        picker.dismiss(animated: true) { [weak self] in
            self?.resetPickingState()
            self?.notifyCompletion(uploader: uploader, localPath: nil, statusCode: -1)
        }
    }
}

extension ImageUploaderImpl: SystemPhotoPickerManagerDelegate {
    func systemPhotoPickerManager(_ manager: SystemPhotoPickerManager, didFinishPicking image: UIImage?) {
        guard let uploader = currentUploader else { return }
        guard let image = image else {
            resetPickingState()
            notifyCompletion(uploader: uploader, localPath: nil, statusCode: -1)
            return
        }
        presentCropView(with: image)
    }
}

extension ImageUploaderImpl: ImageUploaderCropViewControllerDelegate {
    func imageCropViewController(_ viewController: ImageUploaderCropViewController, didFinishCroppingImage image: UIImage) {
        guard let uploader = currentUploader else { return }
        let path = saveImageToLocal(image)
        dismissPresentedVC {
            uploader.delegate?.imageUploaderDidCompletedPick(uploader, localPath: path)
            if let path = path, let uploadURL = self.currentCosUploadURL {
                Task { [weak self, weak uploader] in
                    guard let self = self, let uploader = uploader else { return }
                    let statusCode = await self.uploadManager.uploadFile(localPath: path, presignedURL: uploadURL)
                    uploader.delegate?.imageUploaderDidCompletedCosUpload(uploader, statusCode: statusCode)
                }
            } else {
                uploader.delegate?.imageUploaderDidCompletedCosUpload(uploader, statusCode: -1)
            }
        }
    }
    
    func imageCropViewControllerDidCancel(_ viewController: ImageUploaderCropViewController) {
        guard let uploader = currentUploader else { return }
        dismissPresentedVC { [weak self] in
            self?.notifyCompletion(uploader: uploader, localPath: nil, statusCode: -1)
        }
    }
    
    func saveImageToLocal(_ image: UIImage?) -> String? {
        guard let image = image, let data = image.jpegData(compressionQuality: 1.0) else { return nil }
        let tempDir = NSTemporaryDirectory() + "ImageUploader/"
        let fileName = "\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 0..<Int.max)).jpg"
        let path = tempDir + fileName
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            return path
        } catch {
            return nil
        }
    }
}

//  Created by eddard on 2025/10/21.
//  Copyright © 2025 Tencent. All rights reserved.

import Foundation
import UIKit
import Photos
import PhotosUI

protocol SystemPhotoPickerManagerDelegate: AnyObject {
    func systemPhotoPickerManager(_ manager: SystemPhotoPickerManager, didFinishPicking image: UIImage?)
}

internal class SystemPhotoPickerManager: NSObject {
    weak var delegate: SystemPhotoPickerManagerDelegate?
    
    func pickSingleImage(presenter: UIViewController) {
        if #available(iOS 14, *) {
            pickFromPHPicker(presenter: presenter)
        } else {
            pickFromUIImagePicker(presenter: presenter)
        }
    }
}

// MARK: - PHPickerViewController (iOS 14+)
@available(iOS 14, *)
extension SystemPhotoPickerManager: PHPickerViewControllerDelegate {
    func pickFromPHPicker(presenter: UIViewController) {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        presenter.present(picker, animated: true)
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let first = results.first,
              first.itemProvider.canLoadObject(ofClass: UIImage.self) else {
            dismissAndCallback(picker, image: nil)
            return
        }
        
        first.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.dismissAndCallback(picker, image: object as? UIImage, animated: false)
            }
        }
    }
}

// MARK: - UIImagePickerController (iOS 13 and below)
extension SystemPhotoPickerManager: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    fileprivate func pickFromUIImagePicker(presenter: UIViewController) {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.delegate = self
        picker.modalPresentationStyle = .fullScreen
        presenter.present(picker, animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let resultImage = info[.originalImage] as? UIImage
        dismissAndCallback(picker, image: resultImage, animated: false)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismissAndCallback(picker, image: nil)
    }
}

private extension SystemPhotoPickerManager {
    func dismissAndCallback(_ picker: UIViewController, image: UIImage?, animated: Bool = true) {
        picker.dismiss(animated: animated) { [weak self] in
            guard let self = self else { return }
            self.delegate?.systemPhotoPickerManager(self, didFinishPicking: image)
        }
    }
}

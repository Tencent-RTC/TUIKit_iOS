import AlbumPickerCore
import AVFoundation
import Combine
import UIKit

internal protocol CameraCaptureDelegate: AnyObject {
    func cameraCaptureDidRequestShowPreview(_ capture: AlbumPickerCameraCapture)
}

internal class AlbumPickerCameraCapture: NSObject {

    internal weak var delegate: CameraCaptureDelegate?

    private let store: AlbumPickerStore
    private let mediaFilter: AlbumPickerMediaFilter
    private var cancellable: AnyCancellable?
    private var capturedMediaIds: Set<String> = []

    internal init(store: AlbumPickerStore, mediaFilter: AlbumPickerMediaFilter) {
        self.store = store
        self.mediaFilter = mediaFilter
        super.init()
    }

    internal func scheduleWarmUp() {
        cancellable = store.state.$currentAlbum
            .receive(on: DispatchQueue.main)
            .first(where: { !$0.mediaModels.isEmpty })
            .sink { [weak self] _ in
                self?.warmUpCamera()
            }
    }

    internal func presentCamera(from viewController: UIViewController) {
        guard UIImagePickerController
            .isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = cameraMediaTypes()
        picker.videoQuality = .typeHigh
        picker.delegate = self
        viewController.present(picker, animated: true)
    }

    internal func removeCapturedMedias() {
        guard !capturedMediaIds.isEmpty else { return }
        let currentSelected = store.state.selectedMedias
        store.updateSelectedMedias(
            currentSelected.filter {
                !capturedMediaIds.contains($0.media.id)
            }
        )
        capturedMediaIds.removeAll()
    }

    internal func clearCapturedMediaIds() {
        capturedMediaIds.removeAll()
    }
}

extension AlbumPickerCameraCapture: UIImagePickerControllerDelegate,
UINavigationControllerDelegate {
    internal func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let mediaType = info[.mediaType] as? String ?? ""
        if mediaType == "public.movie" {
            handleCapturedVideo(info: info, picker: picker)
        } else {
            handleCapturedImage(info: info, picker: picker)
        }
    }

    internal func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

private extension AlbumPickerCameraCapture {
    func warmUpCamera() {
        guard AVCaptureDevice.authorizationStatus(for: .video)
            == .authorized else { return }
        guard UIImagePickerController
            .isSourceTypeAvailable(.camera) else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.performCameraWarmUp()
        }
    }

    func performCameraWarmUp() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)
        session.startRunning()
        session.stopRunning()
    }

    func cameraMediaTypes() -> [String] {
        switch mediaFilter {
        case .imageOnly:
            ["public.image"]
        case .videoOnly:
            ["public.movie"]
        case .imageAndVideo:
            ["public.image", "public.movie"]
        }
    }
}

private extension AlbumPickerCameraCapture {
    func handleCapturedImage(
        info: [UIImagePickerController.InfoKey: Any],
        picker: UIImagePickerController
    ) {
        guard let image = info[.originalImage] as? UIImage else {
            picker.dismiss(animated: true)
            return
        }
        let localPath = AlbumPickerStore.saveImageToCache(image)
        var mediaModel = AlbumMediaModel()
        mediaModel.id = UUID().uuidString
        mediaModel.type = .photo
        mediaModel.mediaPath = localPath
        picker.dismiss(animated: false) { [weak self] in
            self?.notifyCapture([mediaModel])
        }
    }

    func handleCapturedVideo(
        info: [UIImagePickerController.InfoKey: Any],
        picker: UIImagePickerController
    ) {
        guard let videoURL = info[.mediaURL] as? URL else {
            picker.dismiss(animated: true)
            return
        }
        picker.dismiss(animated: false) { [weak self] in
            self?.processVideoInBackground(videoURL: videoURL)
        }
    }

    func processVideoInBackground(videoURL: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let thumbnailPath = self?.generateVideoThumbnail(from: videoURL)
            let duration = Int32(
                CMTimeGetSeconds(AVAsset(url: videoURL).duration)
            )
            var mediaModel = AlbumMediaModel()
            mediaModel.id = UUID().uuidString
            mediaModel.type = .video
            mediaModel.mediaPath = videoURL.path
            mediaModel.videoThumbnailPath = thumbnailPath
            mediaModel.duration = duration
            DispatchQueue.main.async { [weak self] in
                self?.notifyCapture([mediaModel])
            }
        }
    }

    func notifyCapture(_ capturedMediaModels: [AlbumMediaModel]) {
        capturedMediaModels.forEach { capturedMediaIds.insert($0.id) }
        let currentSelected = store.state.selectedMedias
        let newItems = capturedMediaModels.map { media -> SelectedMediaItem in
            var item = SelectedMediaItem()
            item.media = media
            return item
        }
        store.updateSelectedMedias(currentSelected + newItems)

        let selected = store.state.selectedMedias.map(\.media)
        guard !selected.isEmpty else { return }
        store.updateCurrentPreviewMedia(capturedMediaModels.first)
        store.updatePreviewMedias(selected)
        delegate?.cameraCaptureDidRequestShowPreview(self)
    }

    func generateVideoThumbnail(from url: URL) -> String? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)
        do {
            let cgImage = try generator.copyCGImage(
                at: .zero, actualTime: nil
            )
            return AlbumPickerStore.saveImageToCache(
                UIImage(cgImage: cgImage)
            )
        } catch {
            return nil
        }
    }
}

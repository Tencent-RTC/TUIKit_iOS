import AlbumPickerCore
import Photos
import UIKit

internal protocol WeChatAlbumPickerPreviewViewDelegate: AnyObject {
    func previewViewDidSend(_ view: WeChatAlbumPickerPreviewView)
    func previewViewDidDismiss(_ view: WeChatAlbumPickerPreviewView)
}

internal class WeChatAlbumPickerPreviewView: UIView {

    private static let bottomBarHeight: CGFloat = 50
    private static let editViewAnimationDuration: TimeInterval = 0.2
    internal weak var delegate: WeChatAlbumPickerPreviewViewDelegate?

    private let store: AlbumPickerStore
    private var isPreviewFromSelection = false
    private var imageEditView: ImageEditView?
    fileprivate var editBridges: [ImageEditBridge] = []

    private lazy var common: AlbumPickerPreviewViewCommon = .init(
        container: self,
        store: store,
        headerView: headerView,
        bottomBarView: bottomBar,
        bottomBarHeight: Self.bottomBarHeight
    )

    private lazy var headerView: WeChatPreviewHeaderView = {
        let header = WeChatPreviewHeaderView(store: store)
        header.delegate = self
        return header
    }()

    private lazy var bottomBar: WeChatBottomBar = {
        let bar = WeChatBottomBar(
            store: store, isPreview: true
        )
        bar.delegate = self
        return bar
    }()

    internal init(store: AlbumPickerStore) {
        self.store = store
        super.init(frame: .zero)
        backgroundColor = AlbumPickerCoreTheme.previewBackgroundColor
        isHidden = true
        _ = common
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func show(isPreviewFromSelection: Bool) {
        self.isPreviewFromSelection = isPreviewFromSelection
        headerView.startObserving()
        common.show(isPreviewFromSelection: isPreviewFromSelection)
    }

    internal func hide() {
        if imageEditView != nil {
            imageEditView?.removeFromSuperview()
            imageEditView = nil
            editBridges.removeAll()
        }
        common.hide()
        delegate?.previewViewDidDismiss(self)
    }

    private func handleBackPressed() -> Bool {
        guard !isHidden else { return false }
        hide()
        return true
    }
}

private extension WeChatAlbumPickerPreviewView {
    func handleSelectTap() {
        guard let currentMedia = store.state
            .currentPreviewMedia else { return }

        if isPreviewFromSelection {
            togglePendingRemoval(for: currentMedia)
        } else {
            let result = store.toggleMediaSelection(media: currentMedia)
            handleSelectionResult(result)
        }
    }

    func handleSelectionResult(_ result: MediaSelectionResult) {
        AlbumPickerMainViewCommon.showSelectionFailedAlert(
            result: result, store: store, from: parentViewController
        )
    }

    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let controller = next as? UIViewController { return controller }
            responder = next
        }
        return nil
    }

    func handleSend() {
        let selected = store.state.selectedMedias
            .filter { !$0.isPendingRemoval }
        guard !selected.isEmpty else { return }
        common.hide()
        delegate?.previewViewDidSend(self)
    }

    func togglePendingRemoval(for media: AlbumMediaModel) {
        var current = store.state.selectedMedias
        guard let idx = current.firstIndex(
            where: { $0.media.id == media.id }
        ) else { return }
        current[idx].isPendingRemoval = !current[idx].isPendingRemoval
        store.updateSelectedMedias(current)
    }
}

// MARK: - WeChatPreviewHeaderViewDelegate

extension WeChatAlbumPickerPreviewView: WeChatPreviewHeaderViewDelegate {
    func previewHeaderViewDidTapBack(_ view: WeChatPreviewHeaderView) {
        hide()
    }

    func previewHeaderViewDidTapSelect(_ view: WeChatPreviewHeaderView) {
        handleSelectTap()
    }
}

// MARK: - WeChatBottomBarDelegate

extension WeChatAlbumPickerPreviewView: WeChatBottomBarDelegate {
    func bottomBarDidTapSend(_ bar: WeChatBottomBar) {
        handleSend()
    }

    func bottomBarDidTapPreview(_ bar: WeChatBottomBar) {}

    func bottomBarDidTapEdit(_ bar: WeChatBottomBar) {
        showImageEditView()
    }
}

// MARK: - Image edit entry

private extension WeChatAlbumPickerPreviewView {
    func showImageEditView() {
        guard imageEditView == nil else { return }
        guard let currentMedia = store.state.currentPreviewMedia else { return }
        if currentMedia.type == .video { return }
        if let edited = currentMedia.editedImage {
            presentEditView(with: edited, media: currentMedia)
            return
        }
        loadEditImage(for: currentMedia)
    }

    func loadEditImage(for media: AlbumMediaModel) {
        guard let asset = media.asset else {
            loadEditImageFromLocalFile(for: media)
            return
        }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        let targetSize = Self.editTargetPixelSize()
        PHImageManager.default().requestImage(
            for: asset, targetSize: targetSize,
            contentMode: .aspectFit, options: options
        ) { [weak self] image, info in
            guard let image else { return }
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            DispatchQueue.main.async {
                self?.handleEditImageDelivery(
                    image: image, isDegraded: isDegraded, media: media
                )
            }
        }
    }

    func loadEditImageFromLocalFile(for media: AlbumMediaModel) {
        if let edited = media.editedImage {
            presentEditView(with: edited, media: media)
            return
        }
        guard let path = media.mediaPath else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let image = UIImage(contentsOfFile: path) else { return }
            DispatchQueue.main.async {
                self?.handleEditImageDelivery(
                    image: image, isDegraded: false, media: media
                )
            }
        }
    }

    func handleEditImageDelivery(image: UIImage, isDegraded: Bool,
                                 media: AlbumMediaModel) {
        guard let latest = store.state.currentPreviewMedia,
              latest.id == media.id else { return }
        if imageEditView == nil {
            presentEditView(with: image, media: latest)
        } else if !isDegraded {
            imageEditView?.updateSourceImage(image)
        }
    }

    static func editTargetPixelSize() -> CGSize {
        let cap = editTargetCap()
        return CGSize(width: cap, height: cap)
    }

    static func editTargetCap() -> CGFloat {
        let physicalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0 / 1024.0
        if physicalGB >= 6.0 {
            return 4096
        } else if physicalGB >= 4.0 {
            return 3072
        } else if physicalGB >= 3.0 {
            return 2560
        } else {
            return 2048
        }
    }

    func presentEditView(with image: UIImage, media: AlbumMediaModel) {
        let editView = ImageEditView(sourceImage: image)
        let bridge = ImageEditBridge(owner: self, media: media)
        editView.editDelegate = bridge
        editBridges.append(bridge)
        editView.translatesAutoresizingMaskIntoConstraints = false
        editView.alpha = 0
        addSubview(editView)
        NSLayoutConstraint.activate([
            editView.topAnchor.constraint(equalTo: topAnchor),
            editView.bottomAnchor.constraint(equalTo: bottomAnchor),
            editView.leadingAnchor.constraint(equalTo: leadingAnchor),
            editView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        imageEditView = editView
        UIView.animate(withDuration: Self.editViewAnimationDuration) {
            editView.alpha = 1
        }
    }

    func dismissImageEditView() {
        guard let editView = imageEditView else { return }
        imageEditView = nil
        UIView.animate(
            withDuration: Self.editViewAnimationDuration,
            animations: { editView.alpha = 0 },
            completion: { _ in editView.removeFromSuperview() }
        )
        editBridges.removeAll()
    }

    func handleEditCompleted(_ image: UIImage, media: AlbumMediaModel) {
        store.updateEditedImage(media: media, editedImage: image)
        dismissImageEditView()
    }

    func handleEditCancelled() {
        dismissImageEditView()
    }
}

// MARK: - ImageEditDelegate bridge

fileprivate final class ImageEditBridge: NSObject, ImageEditDelegate {
    weak var owner: WeChatAlbumPickerPreviewView?
    let media: AlbumMediaModel

    init(owner: WeChatAlbumPickerPreviewView, media: AlbumMediaModel) {
        self.owner = owner
        self.media = media
    }

    func imageEditView(_ editView: ImageEditView,
                       didCompleteWithImage editedImage: UIImage) {
        owner?.notifyEditCompleted(editedImage, media: media)
    }

    func imageEditViewDidCancel(_ editView: ImageEditView) {
        owner?.notifyEditCancelled()
    }
}

internal extension WeChatAlbumPickerPreviewView {
    func notifyEditCompleted(_ image: UIImage, media: AlbumMediaModel) {
        handleEditCompleted(image, media: media)
    }

    func notifyEditCancelled() {
        handleEditCancelled()
    }
}

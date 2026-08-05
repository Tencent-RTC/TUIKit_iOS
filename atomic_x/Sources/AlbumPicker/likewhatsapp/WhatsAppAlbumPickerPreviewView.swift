import AlbumPickerCore
import Photos
import UIKit

internal protocol WhatsAppAlbumPickerPreviewViewDelegate: AnyObject {
    func previewView(_ view: WhatsAppAlbumPickerPreviewView, didSendWithText textMessage: String?)
    func previewViewDidTapAddMore(_ view: WhatsAppAlbumPickerPreviewView)
    func previewView(
        _ view: WhatsAppAlbumPickerPreviewView,
        didDismissWithText textMessage: String?
    )
}

internal class WhatsAppAlbumPickerPreviewView: UIView {

    private static let bottomBarHeight: CGFloat = 56
    private static let editViewAnimationDuration: TimeInterval = 0.2
    internal weak var delegate: WhatsAppAlbumPickerPreviewViewDelegate?

    private let store: AlbumPickerStore
    private var imageEditView: ImageEditView?
    fileprivate var editBridges: [WhatsAppImageEditBridge] = []

    private lazy var common: AlbumPickerPreviewViewCommon = .init(
        container: self,
        store: store,
        headerView: headerView,
        bottomBarView: bottomBar,
        bottomBarHeight: Self.bottomBarHeight,
        enableThumbnailDelete: true
    )

    private lazy var headerView: WhatsAppPreviewHeaderView = {
        let header = WhatsAppPreviewHeaderView(store: store)
        header.delegate = self
        return header
    }()

    private lazy var bottomBar: WhatsAppBottomBar = {
        let bar = WhatsAppBottomBar(
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

    internal func show() {
        common.show(isPreviewFromSelection: true)
    }

    internal func setTextMessage(_ text: String?) {
        bottomBar.setTextMessage(text)
    }

    internal func getTextMessage() -> String? {
        bottomBar.getTextMessageRaw()
    }

    internal func hide() {
        if imageEditView != nil {
            imageEditView?.removeFromSuperview()
            imageEditView = nil
            editBridges.removeAll()
        }
        let text = bottomBar.getTextMessageRaw()
        common.hide()
        delegate?.previewView(self, didDismissWithText: text)
    }

    private func handleBackPressed() -> Bool {
        guard !isHidden else { return false }
        hide()
        return true
    }
}

extension WhatsAppAlbumPickerPreviewView: WhatsAppPreviewHeaderViewDelegate {
    func previewHeaderViewDidTapBack(_ view: WhatsAppPreviewHeaderView) {
        hide()
    }

    func previewHeaderViewDidTapEdit(_ view: WhatsAppPreviewHeaderView) {
        showImageEditView()
    }
}

extension WhatsAppAlbumPickerPreviewView: WhatsAppBottomBarDelegate {
    func bottomBar(_ bar: WhatsAppBottomBar, didTapSendWithText textMessage: String?) {
        let selected = store.state.selectedMedias
            .filter { !$0.isPendingRemoval }
        guard !selected.isEmpty else { return }
        common.hide()
        delegate?.previewView(self, didSendWithText: textMessage)
    }

    func bottomBarDidTapPreview(_ bar: WhatsAppBottomBar) {}

    func bottomBarDidTapAddMore(_ bar: WhatsAppBottomBar) {
        common.hide()
        delegate?.previewViewDidTapAddMore(self)
    }

    func bottomBar(
        _ bar: WhatsAppBottomBar,
        keyboardHeightChanged height: CGFloat,
        duration: TimeInterval
    ) {
        common.updateBottomBarForKeyboard(
            height: height, duration: duration
        )
    }
}

private extension WhatsAppAlbumPickerPreviewView {
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
        let bridge = WhatsAppImageEditBridge(owner: self, media: media)
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

private final class WhatsAppImageEditBridge: NSObject, ImageEditDelegate {
    weak var owner: WhatsAppAlbumPickerPreviewView?
    let media: AlbumMediaModel

    init(owner: WhatsAppAlbumPickerPreviewView, media: AlbumMediaModel) {
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

internal extension WhatsAppAlbumPickerPreviewView {
    func notifyEditCompleted(_ image: UIImage, media: AlbumMediaModel) {
        handleEditCompleted(image, media: media)
    }

    func notifyEditCancelled() {
        handleEditCancelled()
    }
}

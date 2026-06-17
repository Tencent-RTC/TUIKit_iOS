import AlbumPickerCore
import UIKit

internal protocol WeChatAlbumPickerPreviewViewDelegate: AnyObject {
    func previewViewDidSend(_ view: WeChatAlbumPickerPreviewView)
    func previewViewDidDismiss(_ view: WeChatAlbumPickerPreviewView)
}

internal class WeChatAlbumPickerPreviewView: UIView {

    private static let bottomBarHeight: CGFloat = 50
    internal weak var delegate: WeChatAlbumPickerPreviewViewDelegate?

    private let store: AlbumPickerStore
    private var isPreviewFromSelection = false

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
}

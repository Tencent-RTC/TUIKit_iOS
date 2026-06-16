import AlbumPickerCore
import Combine
import UIKit

internal class WeChatAlbumPickerMainView: UIView {

    private static let bottomBarHeight: CGFloat = 50

    private let store: AlbumPickerStore
    private let previewView: WeChatAlbumPickerPreviewView
    private let common: AlbumPickerMainViewCommon
    private let bottomBar: WeChatBottomBar
    private var hasLoadedAlbums = false

    internal init(
        store: AlbumPickerStore,
        previewView: WeChatAlbumPickerPreviewView,
        config: AlbumPickerConfig,
        delegate: AlbumPickerDelegate?
    ) {
        self.store = store
        self.previewView = previewView
        bottomBar = WeChatBottomBar(store: store)
        common = AlbumPickerMainViewCommon(
            store: store, config: config, delegate: delegate
        )
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    internal func setup() {
        let theme = AlbumPickerCoreTheme.shared
        backgroundColor = theme.backgroundColor

        common.setup(
            contentView: self,
            tapMediaToSelect: false,
            mainViewDelegate: self,
            bottomBar: bottomBar,
            bottomBarHeight: Self.bottomBarHeight,
            albumListViewFactory: { [weak self, store] in
                guard let self else { return AlbumListView(store: store) }
                return createAlbumListView()
            }
        )

        bottomBar.delegate = self
        previewView.delegate = self
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, !hasLoadedAlbums {
            hasLoadedAlbums = true
            common.loadAlbums()
            common.updatePermissionUI()
        }
    }

    override func removeFromSuperview() {
        previewView.hide()
        super.removeFromSuperview()
    }
}

private extension WeChatAlbumPickerMainView {
    func createAlbumListView() -> AlbumListView {
        let screen = UIScreen.main.bounds
        let rect = CGRect(
            x: 0, y: 0,
            width: screen.width, height: screen.height
        )
        let theme = AlbumPickerCoreTheme.shared
        let view = AlbumListView(
            store: store,
            albumListRect: rect
        )
        view.backgroundColor = theme.backgroundColorSecondary
        view.layer.cornerRadius = view.intrinsicContentSize.height / 2
        view.clipsToBounds = true
        return view
    }

}

extension WeChatAlbumPickerMainView: AlbumPickerMainViewCommon.Delegate {
    internal func onShowPreview(isPreviewFromSelection: Bool) {
        previewView.show(isPreviewFromSelection: isPreviewFromSelection)
    }
}

// MARK: - WeChatBottomBarDelegate

extension WeChatAlbumPickerMainView: WeChatBottomBarDelegate {
    func bottomBarDidTapSend(_ bar: WeChatBottomBar) {
        common.deliverResult()
    }

    func bottomBarDidTapPreview(_ bar: WeChatBottomBar) {
        let selected = store.state.selectedMedias.map(\.media)
        guard !selected.isEmpty else { return }
        store.updatePreviewMedias(selected)
        store.updateCurrentPreviewMedia(selected.first)
        previewView.show(isPreviewFromSelection: true)
    }
}

// MARK: - WeChatAlbumPickerPreviewViewDelegate

extension WeChatAlbumPickerMainView: WeChatAlbumPickerPreviewViewDelegate {
    func previewViewDidSend(_ view: WeChatAlbumPickerPreviewView) {
        common.deliverResult()
    }

    func previewViewDidDismiss(_ view: WeChatAlbumPickerPreviewView) {
        common.removeCapturedMedias()
    }
}

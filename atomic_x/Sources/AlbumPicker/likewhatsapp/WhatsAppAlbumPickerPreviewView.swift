import AlbumPickerCore
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
    internal weak var delegate: WhatsAppAlbumPickerPreviewViewDelegate?

    private let store: AlbumPickerStore

    private lazy var common: AlbumPickerPreviewViewCommon = .init(
        container: self,
        store: store,
        headerView: headerView,
        bottomBarView: bottomBar,
        bottomBarHeight: Self.bottomBarHeight,
        enableThumbnailDelete: true
    )

    private lazy var headerView: WhatsAppPreviewHeaderView = {
        let header = WhatsAppPreviewHeaderView()
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

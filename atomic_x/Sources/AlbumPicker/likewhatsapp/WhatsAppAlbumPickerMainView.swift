import AlbumPickerCore
import Combine
import UIKit

internal class WhatsAppAlbumPickerMainView: UIView {

    private static let albumListSizeRatio: CGFloat = 0.6
    private static let hdButtonBorderWidth: CGFloat = 1.5
    
    private let store: AlbumPickerStore
    private let previewView: WhatsAppAlbumPickerPreviewView
    private let common: AlbumPickerMainViewCommon
    private var bottomBar: WhatsAppBottomBar!
    private var hdButton: UILabel?
    private var cancellables = Set<AnyCancellable>()
    private var isBottomBarVisible = false
    private var hasLoadedAlbums = false

    internal init(
        store: AlbumPickerStore,
        previewView: WhatsAppAlbumPickerPreviewView,
        config: AlbumPickerConfig,
        delegate: AlbumPickerDelegate?
    ) {
        self.store = store
        self.previewView = previewView
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

        setupBottomBar()
        setupPreviewCallbacks()

        common.setup(
            contentView: self,
            tapMediaToSelect: true,
            mainViewDelegate: self,
            bottomBar: bottomBar,
            albumListViewFactory: { [weak self, store] in
                guard let self else { return AlbumListView(store: store) }
                return createAlbumListView()
            }
        )

        common.updateBottomBarVisibility(isVisible: false)
        observeSelectedMedias()
        setupHdButton()
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

private extension WhatsAppAlbumPickerMainView {
    func createAlbumListView() -> AlbumListView {
        let screen = UIScreen.main.bounds
        let listWidth = screen.width * Self.albumListSizeRatio
        let listHeight = screen.height * Self.albumListSizeRatio
        let left = (screen.width - listWidth) / 2
        let rect = CGRect(
            x: left, y: 0, width: listWidth, height: listHeight
        )
        return AlbumListView(
            store: store,
            albumListRect: rect
        )
    }

    func setupBottomBar() {
        bottomBar = WhatsAppBottomBar(store: store)
        bottomBar.isHidden = true
        bottomBar.delegate = self
    }

    func setupHdButton() {
        let navBar = subviews.first { $0 is UINavigationBar } as? UINavigationBar
        guard let navBar else { return }

        let theme = AlbumPickerCoreTheme.shared

        let container = UIView()
        container.layer.cornerRadius = AlbumPickerCoreTheme.shared.smallRadius
        container.clipsToBounds = true
        container.isUserInteractionEnabled = true

        let label = UILabel()
        label.text = "HD"
        label.font = .systemFont(
            ofSize: theme.normalFontSize, weight: .bold
        )
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        container.addSubview(label)

        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(AlbumPickerCoreTheme.spacing6)
            make.trailing.equalToSuperview().offset(-AlbumPickerCoreTheme.spacing6)
            make.top.equalToSuperview().offset(AlbumPickerCoreTheme.spacing2)
            make.bottom.equalToSuperview().offset(-AlbumPickerCoreTheme.spacing2)
        }

        let tap = UITapGestureRecognizer(
            target: self, action: #selector(handleHdToggle)
        )
        container.addGestureRecognizer(tap)

        navBar.addSubview(container)
        container.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(
                -AlbumPickerCoreTheme.spacing16
            )
            make.centerY.equalToSuperview()
        }

        hdButton = label
        updateHdButtonState()
    }

    func updateHdButtonState() {
        let theme = AlbumPickerCoreTheme.shared
        guard let hdButton, let container = hdButton.superview else { return }
        if store.state.isOriginalSelected {
            hdButton.textColor = .white
            container.backgroundColor = theme.currentPrimaryColor
            container.layer.borderWidth = 0
        } else {
            hdButton.textColor = theme.textColor
            container.backgroundColor = .clear
            container.layer.borderWidth = Self.hdButtonBorderWidth
            container.layer.borderColor = theme.textColorSecondary.cgColor
        }
    }

    @objc func handleHdToggle() {
        let toggled = store.toggleOriginalSelection()
        guard !toggled else { return }
        let size = store.config.maxOutputFileSizeInMB
        let message = String(
            format: "original_oversized_blocked".albumPickerLocalized(),
            size
        )
        let buttonTitle = "i_know".albumPickerLocalized()
        let alert = UIAlertController(
            title: nil, message: message, preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: buttonTitle, style: .default))
        parentViewController?.present(alert, animated: true)
    }

    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let controller = next as? UIViewController { return controller }
            responder = next
        }
        return nil
    }

    func setupPreviewCallbacks() {
        previewView.delegate = self
    }

    func observeSelectedMedias() {
        store.state.$selectedMedias
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedMedias in
                guard let self else { return }
                handleSelectionChanged(!selectedMedias.isEmpty)
            }
            .store(in: &cancellables)

        store.state.$isOriginalSelected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateHdButtonState()
            }
            .store(in: &cancellables)
    }

    func handleSelectionChanged(_ hasSelection: Bool) {
        guard hasSelection != isBottomBarVisible else { return }
        isBottomBarVisible = hasSelection
        bottomBar.isHidden = !hasSelection
        common.updateBottomBarVisibility(isVisible: hasSelection)
    }
}

extension WhatsAppAlbumPickerMainView: AlbumPickerMainViewCommon.Delegate {
    internal func onShowPreview(isPreviewFromSelection: Bool) {
        let text = bottomBar.getTextMessageRaw()
        previewView.setTextMessage(text)
        bottomBar.hideSelectedThumbnails()
        previewView.show()
    }
}

// MARK: - WhatsAppBottomBarDelegate

extension WhatsAppAlbumPickerMainView: WhatsAppBottomBarDelegate {
    func bottomBar(_ bar: WhatsAppBottomBar, didTapSendWithText textMessage: String?) {
        common.deliverResult(textMessage: textMessage)
    }

    func bottomBarDidTapPreview(_ bar: WhatsAppBottomBar) {
        let selected = store.state.selectedMedias.map(\.media)
        guard !selected.isEmpty else { return }
        store.updatePreviewMedias(selected)
        store.updateCurrentPreviewMedia(selected.first)
        let text = bottomBar.getTextMessageRaw()
        previewView.setTextMessage(text)
        bottomBar.hideSelectedThumbnails()
        previewView.show()
    }

    func bottomBarDidTapAddMore(_ bar: WhatsAppBottomBar) {}

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

// MARK: - WhatsAppAlbumPickerPreviewViewDelegate

extension WhatsAppAlbumPickerMainView: WhatsAppAlbumPickerPreviewViewDelegate {
    func previewView(_ view: WhatsAppAlbumPickerPreviewView, didSendWithText textMessage: String?) {
        common.deliverResult(textMessage: textMessage)
    }

    func previewViewDidTapAddMore(_ view: WhatsAppAlbumPickerPreviewView) {
        let medias = store.state.selectedMedias.map(\.media)
        bottomBar.showSelectedThumbnails(medias)
    }

    func previewView(
        _ view: WhatsAppAlbumPickerPreviewView,
        didDismissWithText textMessage: String?
    ) {
        bottomBar.setTextMessage(textMessage)
        common.removeCapturedMedias()
    }
}

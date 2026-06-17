import AlbumPickerCore
import Combine
import Photos
import PhotosUI
import UIKit

internal class AlbumPickerMainViewCommon: NSObject {

    internal protocol Delegate: AnyObject {
        func onShowPreview(isPreviewFromSelection: Bool)
    }

    private static let defaultWeChatItemsPerRow = 3
    private static let defaultWhatsAppItemsPerRow = 3
    private static let limitedBannerHeight: CGFloat = 32
    private let store: AlbumPickerStore
    private let config: AlbumPickerConfig

    private weak var mainViewDelegate: Delegate?
    private weak var pickerDelegate: AlbumPickerDelegate?
    private weak var contentView: UIView?

    private var tapMediaToSelect: Bool = false
    private var albumListViewFactory: (() -> AlbumListView)?
    private var cancellables = Set<AnyCancellable>()
    private var gridViewTopConstraint: Constraint?
    private var permissionSettingsTopConstraint: Constraint?
    private var permissionSettingsBottomConstraint: Constraint?
    private var gridViewBottomConstraint: Constraint?
    private var bottomBarBottomConstraint: Constraint?
    private var cameraCapture: AlbumPickerCameraCapture?

    private weak var hostView: UIView?
    private weak var bottomBarRef: UIView?

    private let statusBarBackground = UIView()
    private let bottomSafeAreaBackground = UIView()

    private lazy var navigationBar: UINavigationBar = {
        let bar = UINavigationBar()
        bar.isTranslucent = false
        bar.backgroundColor = .clear
        return bar
    }()

    private lazy var albumSelectorView: AlbumListView = albumListViewFactory?()
        ?? AlbumListView(store: store)

    private lazy var limitedAccessBanner: UIButton = {
        let button = UIButton(type: .system)
        button.isHidden = true
        return button
    }()

    private lazy var permissionSettingsBanner: UIButton = {
        let button = UIButton(type: .system)
        button.isHidden = true
        return button
    }()

    private var defaultItemsPerRow: Int {
        config.style == .likeWeChat
            ? Self.defaultWeChatItemsPerRow
            : Self.defaultWhatsAppItemsPerRow
    }

    private lazy var gridView: AlbumPickerMediaGridView = .init(
        store: store,
        itemsPerRow: config.itemsPerRow ?? defaultItemsPerRow,
        showsCameraItem: config.showsCameraItem,
        itemClickToSelect: tapMediaToSelect
    )

    internal init(
        store: AlbumPickerStore,
        config: AlbumPickerConfig,
        delegate: AlbumPickerDelegate?
    ) {
        self.store = store
        self.config = config
        pickerDelegate = delegate
        super.init()
    }

    internal func setup(contentView: UIView, tapMediaToSelect: Bool = false,
                        mainViewDelegate: Delegate,
                        bottomBar: UIView, bottomBarHeight: CGFloat? = nil,
                        albumListViewFactory: (() -> AlbumListView)? = nil) {
        self.contentView = contentView
        self.tapMediaToSelect = tapMediaToSelect
        self.mainViewDelegate = mainViewDelegate
        self.albumListViewFactory = albumListViewFactory
        gridView.delegate = self
        bindInteraction()
        constructViewHierarchy(in: contentView, bottomBar: bottomBar)
        activateConstraints(
            in: contentView, bottomBar: bottomBar,
            bottomBarHeight: bottomBarHeight
        )
    }

    internal func loadAlbums() {
        guard checkPhotoLibraryUsageDescription() else { return }
        let isWithVideo = config.mediaFilter != .imageOnly
        let isWithImage = config.mediaFilter != .videoOnly
        store.loadAllAlbums(isWithVideo: isWithVideo, isWithImage: isWithImage)
        if config.showsCameraItem {
            setupCameraCapture()
        }
    }

    private func setupNavigationBar() {
        let navItem = UINavigationItem()
        navItem.titleView = albumSelectorView
        navigationBar.items = [navItem]

        let themeInternal = AlbumPickerCoreTheme.shared
        setupCancelLabel(in: navigationBar, theme: themeInternal)
        configureNavigationBarAppearance(themeInternal)
    }

    private func setupCancelLabel(
        in navBar: UINavigationBar, theme: AlbumPickerCoreTheme
    ) {
        let cancelLabel = UILabel()
        cancelLabel.text = "cancel".albumPickerLocalized()
        cancelLabel.font = .systemFont(
            ofSize: theme.normalFontSize, weight: .medium
        )
        cancelLabel.textColor = theme.textColor
        cancelLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(
            target: self, action: #selector(handleCancel)
        )
        cancelLabel.addGestureRecognizer(tap)
        navBar.addSubview(cancelLabel)
        cancelLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(
                AlbumPickerCoreTheme.spacing16
            )
            make.centerY.equalToSuperview()
        }
    }

    private func configureNavigationBarAppearance(
        _ themeInternal: AlbumPickerCoreTheme
    ) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = themeInternal.backgroundColor
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: themeInternal.textColor,
        ]

        navigationBar.standardAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.tintColor = themeInternal.textColor
    }

    private func configureBanners() {
        configureLimitedAccessBanner()
        configurePermissionSettingsBanner()
    }

    private func configureLimitedAccessBanner() {
        let themeInternal = AlbumPickerCoreTheme.shared
        let bannerExtraInset: CGFloat = 0
        let iconConfig = UIImage.SymbolConfiguration(
            pointSize: themeInternal.smallFontSize, weight: .medium
        )
        let icon = UIImage(
            systemName: "exclamationmark.triangle.fill",
            withConfiguration: iconConfig
        )
        limitedAccessBanner.setImage(icon, for: .normal)
        limitedAccessBanner.setTitle("select_more_photos".albumPickerLocalized(), for: .normal)
        limitedAccessBanner.setTitleColor(themeInternal.textColorSecondary, for: .normal)
        limitedAccessBanner.titleLabel?.font = .systemFont(
            ofSize: themeInternal.smallFontSize,
            weight: .bold
        )
        limitedAccessBanner.tintColor = themeInternal.textColorSecondary
        limitedAccessBanner.backgroundColor = themeInternal.backgroundColorSecondary
        limitedAccessBanner.contentHorizontalAlignment = .leading
        limitedAccessBanner.imageView?.contentMode = .scaleAspectFit
        limitedAccessBanner.contentEdgeInsets = UIEdgeInsets(
            top: AlbumPickerCoreTheme.spacing8 + bannerExtraInset,
            left: AlbumPickerCoreTheme.spacing16,
            bottom: AlbumPickerCoreTheme.spacing8 + bannerExtraInset,
            right: AlbumPickerCoreTheme.spacing16
        )
        limitedAccessBanner.imageEdgeInsets = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: 0,
            right: AlbumPickerCoreTheme.spacing8
        )
        limitedAccessBanner.titleEdgeInsets = UIEdgeInsets(
            top: 0,
            left: AlbumPickerCoreTheme.spacing8,
            bottom: 0,
            right: 0
        )
        limitedAccessBanner.addTarget(
            self,
            action: #selector(handleLimitedAccessTap),
            for: .touchUpInside
        )
    }

    private func configurePermissionSettingsBanner() {
        let themeInternal = AlbumPickerCoreTheme.shared
        let bannerExtraInset: CGFloat = 0
        let iconConfig = UIImage.SymbolConfiguration(
            pointSize: themeInternal.smallFontSize, weight: .medium
        )
        let icon = UIImage(
            systemName: "gearshape.fill",
            withConfiguration: iconConfig
        )
        permissionSettingsBanner.setImage(icon, for: .normal)
        permissionSettingsBanner.setTitle(
            "go_to_settings_for_full_access".albumPickerLocalized(),
            for: .normal
        )
        permissionSettingsBanner.setTitleColor(themeInternal.textColorSecondary, for: .normal)
        permissionSettingsBanner.titleLabel?.font = .systemFont(
            ofSize: themeInternal.smallFontSize,
            weight: .bold
        )
        permissionSettingsBanner.tintColor = themeInternal.textColorSecondary
        permissionSettingsBanner.backgroundColor = themeInternal.backgroundColorSecondary
        permissionSettingsBanner.contentHorizontalAlignment = .leading
        permissionSettingsBanner.imageView?.contentMode = .scaleAspectFit
        permissionSettingsBanner.contentEdgeInsets = UIEdgeInsets(
            top: AlbumPickerCoreTheme.spacing8 + bannerExtraInset,
            left: AlbumPickerCoreTheme.spacing16,
            bottom: AlbumPickerCoreTheme.spacing8 + bannerExtraInset,
            right: AlbumPickerCoreTheme.spacing16
        )
        permissionSettingsBanner.imageEdgeInsets = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: 0,
            right: AlbumPickerCoreTheme.spacing8
        )
        permissionSettingsBanner.titleEdgeInsets = UIEdgeInsets(
            top: 0,
            left: AlbumPickerCoreTheme.spacing8,
            bottom: 0,
            right: 0
        )
        permissionSettingsBanner.addTarget(
            self,
            action: #selector(openSettings),
            for: .touchUpInside
        )
    }

    private func constructViewHierarchy(in view: UIView, bottomBar: UIView) {
        view.addSubview(statusBarBackground)
        view.addSubview(bottomSafeAreaBackground)
        view.addSubview(navigationBar)
        view.addSubview(limitedAccessBanner)
        view.addSubview(permissionSettingsBanner)
        view.addSubview(gridView)
        view.addSubview(bottomBar)
    }

    private func activateConstraints(
        in view: UIView,
        bottomBar: UIView,
        bottomBarHeight: CGFloat? = nil
    ) {
        hostView = view
        bottomBarRef = bottomBar

        let bgColor = AlbumPickerCoreTheme.shared.backgroundColor
        statusBarBackground.backgroundColor = bgColor
        bottomSafeAreaBackground.backgroundColor = bgColor

        activateStatusBarConstraints(in: view)
        activateNavigationBarConstraints(in: view)
        activateBottomBarConstraints(
            in: view,
            bottomBar: bottomBar,
            bottomBarHeight: bottomBarHeight
        )
        activateGridAndPermissionConstraints(in: view, bottomBar: bottomBar)
        setupNavigationBar()
        configureBanners()
        albumSelectorView.containerView = contentView
    }

    private func activateStatusBarConstraints(in view: UIView) {
        statusBarBackground.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(
                view.safeAreaLayoutGuide.snp.top
            )
        }
        bottomSafeAreaBackground.snp.makeConstraints { make in
            make.top.equalTo(
                view.safeAreaLayoutGuide.snp.bottom
            )
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func activateNavigationBarConstraints(in view: UIView) {
        navigationBar.snp.makeConstraints { make in
            make.top.equalTo(
                view.safeAreaLayoutGuide.snp.top
            )
            make.leading.trailing.equalToSuperview()
        }

        limitedAccessBanner.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.limitedBannerHeight)
        }

        permissionSettingsBanner.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            permissionSettingsTopConstraint = make.top.equalTo(
                navigationBar.snp.bottom
            ).constraint
        }
    }

    private func activateBottomBarConstraints(
        in view: UIView,
        bottomBar: UIView,
        bottomBarHeight: CGFloat?
    ) {
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            bottomBarBottomConstraint = make.bottom.equalTo(
                view.safeAreaLayoutGuide.snp.bottom
            ).constraint
            if let height = bottomBarHeight {
                make.height.equalTo(height)
            }
        }
    }

    private func activateGridAndPermissionConstraints(in view: UIView, bottomBar: UIView) {
        gridView.snp.makeConstraints { make in
            gridViewTopConstraint = make.top.equalTo(
                navigationBar.snp.bottom
            ).constraint
            make.leading.trailing.equalToSuperview()
            gridViewBottomConstraint = make.bottom.equalTo(
                bottomBar.snp.top
            ).constraint
        }
    }

    internal func updatePermissionUI() {
        let accessState = store.state.photoAccessState
        let isLimited = accessState == .limited
        let isDenied = accessState == .denied
        let isBottomBarVisible = bottomBarRef?.isHidden == false

        gridViewTopConstraint?.deactivate()
        gridViewBottomConstraint?.deactivate()
        permissionSettingsTopConstraint?.deactivate()
        permissionSettingsBottomConstraint?.deactivate()

        if isLimited {
            setupLimitedPermissionConstraints(
                isBottomBarVisible: isBottomBarVisible
            )
        } else if isDenied {
            setupDeniedPermissionConstraints(
                isBottomBarVisible: isBottomBarVisible
            )
        } else {
            setupAuthorizedConstraints(
                isBottomBarVisible: isBottomBarVisible
            )
        }
    }

    private func setupLimitedPermissionConstraints(isBottomBarVisible: Bool) {
        if isBottomBarVisible, let bar = bottomBarRef {
            permissionSettingsBanner.snp.makeConstraints { make in
                permissionSettingsBottomConstraint = make.bottom
                    .equalTo(bar.snp.top).constraint
            }
        } else if let host = hostView {
            permissionSettingsBanner.snp.makeConstraints { make in
                permissionSettingsBottomConstraint = make.bottom
                    .equalTo(
                        host.safeAreaLayoutGuide.snp.bottom
                    ).constraint
            }
        }
        gridView.snp.makeConstraints { make in
            gridViewTopConstraint = make.top.equalTo(
                limitedAccessBanner.snp.bottom
            ).constraint
            gridViewBottomConstraint = make.bottom.equalTo(
                permissionSettingsBanner.snp.top
            ).constraint
        }
    }

    private func setupDeniedPermissionConstraints(isBottomBarVisible: Bool) {
        permissionSettingsBanner.snp.makeConstraints { make in
            permissionSettingsTopConstraint = make.top
                .equalTo(navigationBar.snp.bottom).constraint
        }
        gridView.snp.makeConstraints { make in
            gridViewTopConstraint = make.top.equalTo(
                permissionSettingsBanner.snp.bottom
            ).constraint
            if isBottomBarVisible, let bar = bottomBarRef {
                gridViewBottomConstraint = make.bottom
                    .equalTo(bar.snp.top).constraint
            } else {
                gridViewBottomConstraint = make.bottom
                    .equalToSuperview().constraint
            }
        }
    }

    private func setupAuthorizedConstraints(isBottomBarVisible: Bool) {
        gridView.snp.makeConstraints { make in
            gridViewTopConstraint = make.top.equalTo(
                navigationBar.snp.bottom
            ).constraint
            if isBottomBarVisible, let bar = bottomBarRef {
                gridViewBottomConstraint = make.bottom
                    .equalTo(bar.snp.top).constraint
            } else {
                gridViewBottomConstraint = make.bottom
                    .equalToSuperview().constraint
            }
        }
    }

    internal func updateBottomBarVisibility(isVisible: Bool) {
        guard let view = hostView else { return }
        bottomSafeAreaBackground.isHidden = !isVisible
        let isLimited = store.state.photoAccessState == .limited

        gridViewBottomConstraint?.deactivate()
        permissionSettingsBottomConstraint?.deactivate()

        if isLimited {
            if isVisible, let bar = bottomBarRef {
                permissionSettingsBanner.snp.makeConstraints { make in
                    permissionSettingsBottomConstraint = make
                        .bottom.equalTo(bar.snp.top).constraint
                }
            } else {
                permissionSettingsBanner.snp.makeConstraints { make in
                    permissionSettingsBottomConstraint = make
                        .bottom.equalTo(
                            view.safeAreaLayoutGuide.snp.bottom
                        ).constraint
                }
            }
            gridView.snp.makeConstraints { make in
                gridViewBottomConstraint = make.bottom.equalTo(
                    permissionSettingsBanner.snp.top
                ).constraint
            }
        } else if isVisible, let bar = bottomBarRef {
            gridView.snp.makeConstraints { make in
                gridViewBottomConstraint = make.bottom
                    .equalTo(bar.snp.top).constraint
            }
        } else {
            gridView.snp.makeConstraints { make in
                gridViewBottomConstraint =
                    make.bottom.equalToSuperview().constraint
            }
        }
        view.layoutIfNeeded()
    }

    internal func updateBottomBarForKeyboard(height: CGFloat, duration: TimeInterval) {
        guard let view = hostView else { return }
        let safeBottom = view.safeAreaInsets.bottom
        let offset = height > 0 ? -(height - safeBottom) : 0
        bottomBarBottomConstraint?.update(offset: offset)
        UIView.animate(withDuration: duration) {
            view.layoutIfNeeded()
        }
    }

    internal func deliverResult(textMessage: String? = nil) {
        cameraCapture?.clearCapturedMediaIds()
        let selectedMedias = store.state.selectedMedias
            .filter { !$0.isPendingRemoval }
        store.updateSelectedMedias(selectedMedias)
        let albumMedias: [AlbumMedia] = selectedMedias.map { item in
            let isVideo = item.media.type == .video
            return AlbumMedia(
                id: UInt64(abs(item.media.id.hashValue)),
                asset: item.media.asset,
                mediaPath: item.media.mediaPath,
                mediaType: isVideo ? .video : .image,
                videoThumbnailPath: item.media.videoThumbnailPath,
                duration: Int64(item.media.duration)
            )
        }
        pickerDelegate?.onPickConfirm(pickedAlbumMedias: albumMedias, textMessage: textMessage)

        store.processSelectedMedias(
            listener: MediaProcessBridge(
                albumMedias: albumMedias,
                delegate: pickerDelegate
            )
        )
    }

    internal func removeCapturedMedias() {
        cameraCapture?.removeCapturedMedias()
    }
    
    private var parentViewController: UIViewController? {
        var responder: UIResponder? = contentView
        while let next = responder?.next {
            if let controller = next as? UIViewController { return controller }
            responder = next
        }
        return nil
    }
    
    internal static func showSelectionFailedAlert(
        result: MediaSelectionResult,
        store: AlbumPickerStore,
        from viewController: UIViewController?
    ) {
        let message: String
        switch result {
        case .success:
            return
        case .videoDurationExceeded:
            let minutes = store.config.maxVideoDurationInSeconds / 60
            message = String(
                format: "video_duration_exceeded".albumPickerLocalized(),
                minutes
            )
        case .fileSizeExceeded:
            let size = store.config.maxOutputFileSizeInMB
            message = String(
                format: "file_size_exceeded".albumPickerLocalized(),
                size
            )
        case .maxSelectionCountExceeded:
            let count = store.config.maxSelectionCount
            message = String(
                format: "max_selection_exceeded".albumPickerLocalized(),
                count
            )
        }
        let buttonTitle = "i_know".albumPickerLocalized()
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: buttonTitle, style: .default))
        viewController?.present(alert, animated: true)
    }
}

private extension AlbumPickerMainViewCommon {
    
    func checkPhotoLibraryUsageDescription() -> Bool {
        if let value = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") as? String,
           !value.isEmpty {
            return true
        }
        showMissingPermissionDescriptionAlert()
        return false
    }

    func showMissingPermissionDescriptionAlert() {
        guard let viewController = parentViewController else {
            assertionFailure("[AlbumPicker] NSPhotoLibraryUsageDescription is not set in Info.plist.")
            return
        }
        let alert = UIAlertController(
            title: "Missing Permission Description",
            message: "NSPhotoLibraryUsageDescription is not set in Info.plist. "
                + "Please add this key with a non-empty value to access the photo library.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }

    func bindInteraction() {
        store.state.$photoAccessState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] accessState in
                self?.limitedAccessBanner.isHidden = accessState != .limited
                self?.permissionSettingsBanner
                    .isHidden = accessState != .limited && accessState != .denied
                self?.updatePermissionUI()
            }
            .store(in: &cancellables)
    }

    @objc func handleCancel() {
        pickerDelegate?.onCancel()
    }

    @objc func handleLimitedAccessTap() {
        guard let viewController = parentViewController else { return }
        if #available(iOS 14, *) {
            PHPhotoLibrary.shared()
                .presentLimitedLibraryPicker(from: viewController)
        }
    }

    @objc func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func setupCameraCapture() {
        guard cameraCapture == nil else { return }
        let capture = AlbumPickerCameraCapture(
            store: store, mediaFilter: config.mediaFilter
        )
        capture.delegate = self
        capture.scheduleWarmUp()
        cameraCapture = capture
    }
}

private class MediaProcessBridge: AlbumPickerMediaProcessListener {
    private let albumMedias: [AlbumMedia]
    private weak var delegate: AlbumPickerDelegate?

    fileprivate init(albumMedias: [AlbumMedia], delegate: AlbumPickerDelegate?) {
        self.albumMedias = albumMedias
        self.delegate = delegate
    }

    fileprivate func onMediaProcessing(media: AlbumMediaModel, progress: Float, error: Bool) {
        let matchId = UInt64(abs(media.id.hashValue))
        guard let albumMedia = albumMedias
            .first(where: { $0.id == matchId }) else { return }
        albumMedia.mediaPath = media.mediaPath
        albumMedia.videoThumbnailPath = media.videoThumbnailPath
        delegate?.onMediaProcessing(
            albumMedia: albumMedia, progress: progress, error: error
        )
    }

    fileprivate func onMediaProcessed() {
        delegate?.onMediaProcessed()
    }
}

extension AlbumPickerMainViewCommon: AlbumPickerMediaGridViewDelegate {
    internal func mediaGridView(_ gridView: AlbumPickerMediaGridView, didClickMedia media: AlbumMediaModel) {
        let medias = store.state.currentAlbum.mediaModels
        store.updatePreviewMedias(medias)
        store.updateCurrentPreviewMedia(media)
        mainViewDelegate?.onShowPreview(isPreviewFromSelection: false)
    }

    internal func mediaGridViewDidClickCamera(_ gridView: AlbumPickerMediaGridView) {
        guard let viewController = parentViewController
        else { return }
        cameraCapture?.presentCamera(from: viewController)
    }

    internal func mediaGridView(_ gridView: AlbumPickerMediaGridView, didFailSelection result: MediaSelectionResult) {
        Self.showSelectionFailedAlert(
            result: result, store: store, from: parentViewController
        )
    }
}

extension AlbumPickerMainViewCommon: CameraCaptureDelegate {
    func cameraCaptureDidRequestShowPreview(
        _ capture: AlbumPickerCameraCapture
    ) {
        mainViewDelegate?.onShowPreview(isPreviewFromSelection: true)
    }
}

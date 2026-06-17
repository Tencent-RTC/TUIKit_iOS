import AlbumPickerCore
import Combine
import UIKit

internal class AlbumPickerPreviewViewCommon {

    private static let barAnimationDuration: TimeInterval = 0.25
    private static let transitionDuration: TimeInterval = 0.40

    private let store: AlbumPickerStore
    private let pagerView: AlbumPickerPreviewPagerView

    private let container: UIView
    private let headerView: UIView
    private let bottomBarView: UIView
    private var barsVisible = true
    private var bottomBarBottomConstraint: Constraint?
    private var bottomBarHeight: CGFloat = 0
    private var keyboardHeight: CGFloat = 0
    private var cancellable: AnyCancellable?

    internal init(
        container: UIView,
        store: AlbumPickerStore,
        headerView: UIView,
        bottomBarView: UIView,
        bottomBarHeight: CGFloat,
        enableThumbnailDelete: Bool = false
    ) {
        self.container = container
        self.store = store
        self.headerView = headerView
        self.bottomBarView = bottomBarView

        pagerView = AlbumPickerPreviewPagerView(
            store: store,
            enableThumbnailDelete: enableThumbnailDelete
        )

        setupLayout(bottomBarHeight: bottomBarHeight)
        pagerView.gestureDelegate = self
    }

    internal func show(isPreviewFromSelection: Bool) {
        showBarsImmediate()
        container.alpha = 0
        container.isHidden = false
        pagerView.refresh()
        UIView.animate(withDuration: Self.transitionDuration) {
            self.container.alpha = 1
        }
        if isPreviewFromSelection {
            observeSelectedMediasEmpty()
        }
    }

    internal func hide() {
        cancellable = nil
        pagerView.cleanupVideoPlayers()
        UIView.animate(
            withDuration: Self.transitionDuration,
            animations: {
                self.container.alpha = 0
            },
            completion: { _ in
                self.container.isHidden = true
                self.container.alpha = 1
            }
        )
        filterPendingRemovals()
    }

    internal func updateBottomBarForKeyboard(height: CGFloat, duration: TimeInterval) {
        keyboardHeight = height
        let safeBottom = container.safeAreaInsets.bottom
        let offset = height > 0 ? -(height - safeBottom) : 0
        bottomBarBottomConstraint?.update(offset: offset)

        let inset = height > 0
            ? bottomBarHeight + height - safeBottom
            : bottomBarHeight
        pagerView.setThumbnailBottomInset(inset)

        UIView.animate(withDuration: duration) {
            self.container.layoutIfNeeded()
        }
    }
}

private extension AlbumPickerPreviewViewCommon {
    func setupLayout(bottomBarHeight: CGFloat) {
        self.bottomBarHeight = bottomBarHeight
        container.addSubview(pagerView)
        container.addSubview(headerView)
        container.addSubview(bottomBarView)

        pagerView.snp.makeConstraints {
            $0.top.equalTo(container.safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(
                container.safeAreaLayoutGuide.snp.bottom
            )
        }
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        bottomBarView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            bottomBarBottomConstraint = make.bottom.equalTo(
                container.safeAreaLayoutGuide.snp.bottom
            ).constraint
            make.height.equalTo(bottomBarHeight)
        }

        pagerView.setThumbnailBottomInset(bottomBarHeight)
    }

    func filterPendingRemovals() {
        let current = store.state.selectedMedias
        let filtered = current.filter { !$0.isPendingRemoval }
        if filtered.count != current.count {
            store.updateSelectedMedias(filtered)
        }
    }

    func observeSelectedMediasEmpty() {
        cancellable = store.state.$selectedMedias
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selectedMedias in
                guard let self else { return }
                guard !container.isHidden else { return }
                if selectedMedias.isEmpty {
                    hide()
                }
            }
    }
}

private extension AlbumPickerPreviewViewCommon {
    func showBarsImmediate() {
        barsVisible = true
        headerView.alpha = 1
        headerView.transform = .identity
        bottomBarView.alpha = 1
        bottomBarView.transform = .identity
        pagerView.animateThumbnailVisibility(
            alpha: 1, translationY: 0
        )
    }

    func toggleBars() {
        if barsVisible { hideBars() } else { showBars() }
    }

    func showBars() {
        guard !barsVisible else { return }
        barsVisible = true

        UIView.animate(
            withDuration: Self.barAnimationDuration
        ) { [self] in
            headerView.alpha = 1
            headerView.transform = .identity
            bottomBarView.alpha = 1
            bottomBarView.transform = .identity
            pagerView.animateThumbnailVisibility(
                alpha: 1, translationY: 0
            )
        }
    }

    func hideBars() {
        guard barsVisible else { return }
        barsVisible = false

        let headerH = headerView.bounds.height
        let footerH = bottomBarView.bounds.height

        UIView.animate(
            withDuration: Self.barAnimationDuration
        ) { [self] in
            headerView.alpha = 0
            headerView.transform = CGAffineTransform(
                translationX: 0, y: -headerH
            )
            bottomBarView.alpha = 0
            bottomBarView.transform = CGAffineTransform(
                translationX: 0, y: footerH
            )
            pagerView.animateThumbnailVisibility(
                alpha: 0, translationY: footerH
            )
        }
    }
}

extension AlbumPickerPreviewViewCommon: AlbumPickerPreviewPagerViewDelegate {
    internal func previewPagerViewDidTap(_ pagerView: AlbumPickerPreviewPagerView) {
        if keyboardHeight > 0 {
            container.endEditing(true)
            return
        }
        showBars()
    }

    internal func previewPagerViewDidLongPress(_ pagerView: AlbumPickerPreviewPagerView) {
        container.endEditing(true)
        hideBars()
    }
}

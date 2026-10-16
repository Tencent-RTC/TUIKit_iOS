import SnapKit
import UIKit

@MainActor
final class GiftListView: UIView {
    typealias GiftItem = GiftUIStore.GiftItem
    typealias GiftCategoryGroup = GiftUIStore.GiftCategoryGroup

    var onSendGift: ((GiftItem, Int) -> Void)?
    var onPresentationChanged: ((Bool, CGFloat) -> Void)?
    /// Called when the user taps a *selected* gift that carries an animation resource
    /// (advanced gift). The panel will dismiss itself; the host is expected to keep the
    /// combo alive via a floating combo button.
    var onAdvancedComboStart: ((GiftItem) -> Void)?

    private let dimmingControl = UIControl()
    private let backgroundView = BottomSheetBackgroundView()
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let balanceContainer = UIView()
    private let balanceCoinDot = UIView()
    private let balanceLabel = UILabel()
    private let categoryTabs = GiftCategoryTabsView()
    private let contentPager = UIScrollView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let emptyLabel = UILabel()

    private var categories: [GiftCategoryGroup] = []
    private var pageViews: [GiftGridPageView] = []
    private var selectedCategoryIndex: Int = 0
    private var selectedGiftID: String?
    private var comboGiftID: String?
    private var isLoading: Bool = false

    private let contentHeightAboveSafeArea: CGFloat = 348
    private var backgroundHeightConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(categories: [GiftCategoryGroup], isLoading: Bool) {
        self.isLoading = isLoading
        let changed = categories != self.categories
        if changed {
            self.categories = categories
            if selectedCategoryIndex >= categories.count {
                selectedCategoryIndex = 0
            }
            categoryTabs.setCategories(categories.map { $0.name })
            categoryTabs.setSelectedIndex(selectedCategoryIndex, animated: false)
            rebuildPages()
            if let gid = selectedGiftID, !allGifts().contains(where: { $0.id == gid }) {
                selectedGiftID = nil
            }
            if let cid = comboGiftID, !allGifts().contains(where: { $0.id == cid }) {
                comboGiftID = nil
            }
            applySelectionToPages()
        }

        let showEmpty = !isLoading && categories.isEmpty
        emptyLabel.isHidden = !showEmpty
        if isLoading && categories.isEmpty {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }

        for (index, page) in pageViews.enumerated() where self.categories.indices.contains(index) {
            page.update(gifts: self.categories[index].gifts)
        }
        applySelectionToPages()
    }

    func present() {
        guard isHidden else { return }
        isHidden = false
        onPresentationChanged?(true, contentHeightAboveSafeArea)
        layoutIfNeeded()
        dimmingControl.alpha = 0
        backgroundView.transform = CGAffineTransform(translationX: 0, y: backgroundView.bounds.height)
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.dimmingControl.alpha = 1
            self.backgroundView.transform = .identity
        }
    }

    @objc func dismiss() {
        guard !isHidden else { return }
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                self.dimmingControl.alpha = 0
                self.backgroundView.transform = CGAffineTransform(
                    translationX: 0,
                    y: self.backgroundView.bounds.height
                )
            },
            completion: { [weak self] _ in
                guard let self else { return }
                self.backgroundView.transform = .identity
                self.isHidden = true
                self.selectedGiftID = nil
                self.endCombo()
                self.applySelectionToPages()
                self.onPresentationChanged?(false, self.contentHeightAboveSafeArea)
            }
        )
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        backgroundHeightConstraint?.update(offset: contentHeightAboveSafeArea + safeAreaInsets.bottom)
    }

    private func configureUI() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        dimmingControl.backgroundColor = LiveTheme.Color.sheetScrim
        dimmingControl.addTarget(self, action: #selector(dismiss), for: .touchUpInside)
        addSubview(dimmingControl)

        addSubview(backgroundView)

        backgroundView.addSubview(headerView)

        titleLabel.text = LiveKitResources.localizedString("tuilivekit.player.gift.title")
        titleLabel.textColor = GiftListStyle.title
        titleLabel.font = GiftListViewTypography.titleFont
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)

        balanceContainer.isHidden = true
        headerView.addSubview(balanceContainer)

        balanceCoinDot.backgroundColor = GiftPanelStyle.coin
        balanceCoinDot.layer.cornerRadius = 5
        balanceContainer.addSubview(balanceCoinDot)

        balanceLabel.font = GiftListViewTypography.balanceFont
        balanceLabel.textColor = GiftListStyle.balance
        balanceContainer.addSubview(balanceLabel)

        categoryTabs.onSelect = { [weak self] index in
            self?.selectCategory(index, animated: true)
        }
        backgroundView.addSubview(categoryTabs)

        contentPager.isPagingEnabled = true
        contentPager.showsHorizontalScrollIndicator = false
        contentPager.showsVerticalScrollIndicator = false
        contentPager.delaysContentTouches = false
        contentPager.delegate = self
        backgroundView.addSubview(contentPager)

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = GiftListStyle.loading
        backgroundView.addSubview(loadingIndicator)

        emptyLabel.text = LiveKitResources.localizedString("tuilivekit.player.gift.empty")
        emptyLabel.textColor = GiftListStyle.empty
        emptyLabel.font = GiftListViewTypography.emptyFont
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        backgroundView.addSubview(emptyLabel)

        dimmingControl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            self.backgroundHeightConstraint = make.height.equalTo(contentHeightAboveSafeArea).constraint
        }

        headerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(14)
            make.height.equalTo(32)
        }

        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        balanceContainer.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(16)
        }

        balanceCoinDot.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(10)
        }

        balanceLabel.snp.makeConstraints { make in
            make.leading.equalTo(balanceCoinDot.snp.trailing).offset(6)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        categoryTabs.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(headerView.snp.bottom).offset(10)
            make.height.equalTo(32)
        }

        contentPager.snp.makeConstraints { make in
            make.leading.trailing.equalTo(backgroundView)
            make.top.equalTo(categoryTabs.snp.bottom).offset(10)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-20)
        }

        loadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(contentPager)
        }

        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(contentPager)
            make.leading.equalTo(backgroundView).offset(24)
            make.trailing.equalTo(backgroundView).offset(-24)
        }
    }

    private func rebuildPages() {
        pageViews.forEach { $0.removeFromSuperview() }
        pageViews.removeAll()

        for category in categories {
            let page = GiftGridPageView()
            page.onCellTapped = { [weak self] gift in
                self?.handleCellTapped(gift)
            }
            page.onComboSend = { [weak self] gift in
                self?.onSendGift?(gift, 1)
            }
            page.onComboExpired = { [weak self] in
                self?.handleComboExpired()
            }
            page.update(gifts: category.gifts)
            contentPager.addSubview(page)
            pageViews.append(page)
        }
        setNeedsLayout()
    }

    private func layoutPages() {
        let pageWidth = contentPager.bounds.width
        let pageHeight = contentPager.bounds.height
        guard pageWidth > 0, pageHeight > 0 else { return }
        for (index, page) in pageViews.enumerated() {
            page.frame = CGRect(x: pageWidth * CGFloat(index), y: 0, width: pageWidth, height: pageHeight)
        }
        contentPager.contentSize = CGSize(width: pageWidth * CGFloat(pageViews.count), height: pageHeight)
        let offsetX = pageWidth * CGFloat(selectedCategoryIndex)
        if abs(contentPager.contentOffset.x - offsetX) > 0.5 {
            contentPager.setContentOffset(CGPoint(x: offsetX, y: 0), animated: false)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutPages()
    }

    private func selectCategory(_ index: Int, animated: Bool) {
        guard categories.indices.contains(index) else { return }
        if index != selectedCategoryIndex {
            selectedCategoryIndex = index
            endCombo()
            selectedGiftID = nil
            applySelectionToPages()
        }
        let offsetX = contentPager.bounds.width * CGFloat(index)
        contentPager.setContentOffset(CGPoint(x: offsetX, y: 0), animated: animated)
    }

    private func handleCellTapped(_ gift: GiftItem) {
        if comboGiftID != nil {
            comboGiftID = nil
        }
        if selectedGiftID == gift.id {
            // Second tap on the already-selected gift: enter combo.
            // For advanced gifts (with an animation resourceURL), the panel yields
            // to a screen-level floating combo button owned by the host, matching
            // the reference web behavior.
            if gift.resourceURL != nil {
                selectedGiftID = nil
                applySelectionToPages()
                onAdvancedComboStart?(gift)
                dismiss()
            } else {
                selectedGiftID = nil
                comboGiftID = gift.id
                applySelectionToPages()
            }
        } else {
            selectedGiftID = gift.id
            applySelectionToPages()
        }
    }

    private func handleComboExpired() {
        guard let gid = comboGiftID else { return }
        comboGiftID = nil
        selectedGiftID = gid
        applySelectionToPages()
    }

    private func endCombo() {
        comboGiftID = nil
    }

    private func applySelectionToPages() {
        let state: GiftGridPageView.SelectionState
        if let combo = comboGiftID {
            state = .combo(combo)
        } else if let selected = selectedGiftID {
            state = .selected(selected)
        } else {
            state = .none
        }
        for page in pageViews {
            page.setSelection(state)
        }
    }

    private func allGifts() -> [GiftItem] {
        categories.flatMap { $0.gifts }
    }
}

extension GiftListView: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === contentPager, contentPager.bounds.width > 0 else { return }
        let index = Int(round(contentPager.contentOffset.x / contentPager.bounds.width))
        if index != selectedCategoryIndex, categories.indices.contains(index) {
            selectedCategoryIndex = index
            categoryTabs.setSelectedIndex(index, animated: true)
            endCombo()
            selectedGiftID = nil
            applySelectionToPages()
        }
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum GiftListStyle {
    static let title: UIColor = UIColor.white.withAlphaComponent(0.94)
    static let balance: UIColor = UIColor.white.withAlphaComponent(0.82)
    static let loading: UIColor = UIColor.white.withAlphaComponent(0.7)
    static let empty: UIColor = UIColor.white.withAlphaComponent(0.5)
}

private enum GiftListViewTypography {
    static let titleFont: UIFont = UIFont.systemFont(ofSize: 16, weight: .bold)
    static let balanceFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    static let emptyFont: UIFont = UIFont.systemFont(ofSize: 14, weight: .regular)
}

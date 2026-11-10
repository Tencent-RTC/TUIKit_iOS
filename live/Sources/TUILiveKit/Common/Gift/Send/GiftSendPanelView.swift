import AtomicXCore
import Combine
import SnapKit
import UIKit

@MainActor final class GiftSendPanelView: UIView {
    struct GiftItem: Equatable {
        let id: String
        let name: String
        let coins: Int
        let iconURL: URL?
        let resourceURL: URL?
        let categoryID: String
        let categoryName: String
    }

    struct GiftCategoryGroup: Equatable {
        let id: String
        let name: String
        let gifts: [GiftItem]
    }

    private struct State: Equatable {
        var liveID: String?
        var categories: [GiftCategoryGroup] = []
        var isLoading = false
    }

    /// Optional overrides for hosts with custom receivers. When nil the panel owns
    /// catalog loading, sending and the floating combo itself.
    var onSendGift: ((GiftItem, Int) -> Void)?
    var onAdvancedComboStart: ((GiftItem) -> Void)?
    var onPresentationChanged: ((Bool, CGFloat) -> Void)?

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
    private let receiverChip = UIControl()
    private let receiverLabel = UILabel()
    private let receiverCloseView = UIImageView()

    private var categories: [GiftCategoryGroup] = []
    private var pageViews: [GiftGridPageView] = []
    private var selectedCategoryIndex: Int = 0
    private var selectedGiftID: String?
    private var comboGiftID: String?
    private var isLoading: Bool = false
    private(set) var receiverID: String?
    private var receiverChipHeightConstraint: Constraint?

    private var state = State()
    private var giftStore: GiftStore?
    private var cancellables = Set<AnyCancellable>()
    private var activationID = UUID()
    private var liveID = ""
    private var sendReceiverID = ""
    private weak var floatingCombo: GiftSendComboButton?

    private let baseContentHeightAboveSafeArea: CGFloat = 348
    private let receiverChipHeight: CGFloat = 28
    private var contentHeightAboveSafeArea: CGFloat {
        baseContentHeightAboveSafeArea + (receiverID == nil ? 0 : receiverChipHeight)
    }
    private var backgroundHeightConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
        isHidden = true
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func bind(categories: [GiftCategoryGroup], isLoading: Bool) {
        self.isLoading = isLoading
        let changed = categories != self.categories
        if changed {
            self.categories = categories
            if selectedCategoryIndex >= categories.count { selectedCategoryIndex = 0 }
            categoryTabs.setCategories(categories.map { $0.name })
            categoryTabs.setSelectedIndex(selectedCategoryIndex, animated: false)
            rebuildPages()
            if let gid = selectedGiftID, !allGifts().contains(where: { $0.id == gid }) { selectedGiftID = nil }
            if let cid = comboGiftID, !allGifts().contains(where: { $0.id == cid }) { comboGiftID = nil }
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

    private func activate(liveID: String, receiverID: String) {
        guard state.liveID != liveID else {
            self.sendReceiverID = receiverID
            return
        }
        deactivate()
        self.liveID = liveID
        self.sendReceiverID = receiverID
        let activationID = UUID()
        self.activationID = activationID
        state = State(liveID: liveID, isLoading: true)
        bind(categories: state.categories, isLoading: state.isLoading)

        let store = GiftStore.create(liveID: liveID)
        giftStore = store
        store.setLanguage(LiveKitResources.giftLanguageCode)
        store.state.subscribe().receive(on: DispatchQueue.main).sink { [weak self] giftState in
            guard let self, self.activationID == activationID, self.state.liveID == liveID else { return }
            self.applyGiftState(giftState)
        }.store(in: &cancellables)
        store.refreshUsableGifts { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.activationID == activationID, self.state.liveID == liveID else { return }
                self.state.isLoading = false
                self.bind(categories: self.state.categories, isLoading: false)
            }
        }
    }

    private func deactivate() {
        activationID = UUID()
        cancellables.removeAll()
        giftStore = nil
        state = State()
    }

    private func applyGiftState(_ giftState: GiftState) {
        var categories: [GiftCategoryGroup] = []
        for category in giftState.usableGifts {
            let items = category.giftList.map { gift in
                GiftItem(
                    id: gift.giftID, name: gift.name, coins: Int(gift.coins), iconURL: URL(string: gift.iconURL),
                    resourceURL: URL(string: gift.resourceURL), categoryID: category.categoryID,
                    categoryName: category.name)
            }
            categories.append(GiftCategoryGroup(id: category.categoryID, name: category.name, gifts: items))
        }
        state.categories = categories
        if !giftState.usableGifts.isEmpty { state.isLoading = false }
        bind(categories: state.categories, isLoading: state.isLoading)
    }

    private func send(_ gift: GiftItem, count: Int) {
        if let onSendGift {
            onSendGift(gift, count)
            return
        }
        guard let store = giftStore else { return }
        let activationID = self.activationID
        let receiver = receiverID ?? sendReceiverID
        store.sendGift(giftID: gift.id, count: UInt(max(1, count)), receiver: receiver) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.activationID == activationID else { return }
                if case .failure(let error) = result {
                    LiveKitLog.error("Gift send failed: gift=\(gift.id), error=\(error)")
                }
            }
        }
    }

    private func startFloatingCombo(with gift: GiftItem) {
        if let onAdvancedComboStart {
            onAdvancedComboStart(gift)
            return
        }
        endFloatingCombo()
        guard let host = superview else { return }
        let combo = GiftSendComboButton()
        combo.onSendOnce = { [weak self] in self?.send(gift, count: 1) }
        combo.onExpired = { [weak combo] in combo?.removeFromSuperview() }
        host.addSubview(combo)
        combo.snp.makeConstraints { make in
            make.trailing.equalTo(host.safeAreaLayoutGuide.snp.trailing).offset(-16)
            make.bottom.equalTo(host.safeAreaLayoutGuide.snp.bottom).offset(-72)
            make.width.equalTo(72)
            make.height.equalTo(96)
        }
        floatingCombo = combo
        combo.begin(with: gift)
    }

    private func endFloatingCombo() {
        floatingCombo?.end()
        floatingCombo?.removeFromSuperview()
        floatingCombo = nil
    }

    func setReceiver(userID: String?, name: String?) {
        let newID = userID?.isEmpty == false ? userID : nil
        receiverID = newID
        receiverChip.isHidden = newID == nil
        receiverChipHeightConstraint?.update(offset: newID == nil ? 0 : receiverChipHeight)
        if let newID {
            let displayName = name?.isEmpty == false ? name ?? newID : newID
            receiverLabel.text = LiveKitResources.localizedFormat("tuilivekit.common.gift.to_user", displayName)
        }
        backgroundHeightConstraint?.update(offset: contentHeightAboveSafeArea + safeAreaInsets.bottom)
    }

    func present(liveID: String, receiverID: String = "") {
        activate(liveID: liveID, receiverID: receiverID)
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
        endFloatingCombo()
        hidePanel()
        deactivate()
    }

    private func hidePanel() {
        guard !isHidden else { return }
        UIView.animate(
            withDuration: 0.2, delay: 0, options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                self.dimmingControl.alpha = 0
                self.backgroundView.transform = CGAffineTransform(translationX: 0, y: self.backgroundView.bounds.height)
            },
            completion: { [weak self] _ in
                guard let self else { return }
                self.backgroundView.transform = .identity
                self.isHidden = true
                self.selectedGiftID = nil
                self.endCombo()
                self.applySelectionToPages()
                self.onPresentationChanged?(false, self.contentHeightAboveSafeArea)
                self.setReceiver(userID: nil, name: nil)
            })
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
        titleLabel.textColor = GiftSendPanelStyle.title
        titleLabel.font = GiftSendPanelTypography.titleFont
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)

        balanceContainer.isHidden = true
        headerView.addSubview(balanceContainer)

        balanceCoinDot.backgroundColor = GiftPanelStyle.coin
        balanceCoinDot.layer.cornerRadius = 5
        balanceContainer.addSubview(balanceCoinDot)

        balanceLabel.font = GiftSendPanelTypography.balanceFont
        balanceLabel.textColor = GiftSendPanelStyle.balance
        balanceContainer.addSubview(balanceLabel)

        categoryTabs.onSelect = { [weak self] index in self?.selectCategory(index, animated: true) }
        backgroundView.addSubview(categoryTabs)

        receiverChip.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        receiverChip.layer.cornerRadius = 14
        receiverChip.layer.borderWidth = 1
        receiverChip.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        receiverChip.isHidden = true
        receiverChip.addTarget(self, action: #selector(tapReceiverChip), for: .touchUpInside)
        backgroundView.addSubview(receiverChip)

        receiverLabel.font = .systemFont(ofSize: 12, weight: .regular)
        receiverLabel.textColor = UIColor.white.withAlphaComponent(0.86)
        receiverChip.addSubview(receiverLabel)

        receiverCloseView.image = LiveKitResources.image(named: "livekit_living_close")?.withRenderingMode(
            .alwaysTemplate)
        receiverCloseView.tintColor = UIColor.white.withAlphaComponent(0.6)
        receiverCloseView.contentMode = .scaleAspectFit
        receiverChip.addSubview(receiverCloseView)

        contentPager.isPagingEnabled = true
        contentPager.showsHorizontalScrollIndicator = false
        contentPager.showsVerticalScrollIndicator = false
        contentPager.delaysContentTouches = false
        contentPager.delegate = self
        backgroundView.addSubview(contentPager)

        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = GiftSendPanelStyle.loading
        backgroundView.addSubview(loadingIndicator)

        emptyLabel.text = LiveKitResources.localizedString("tuilivekit.player.gift.empty")
        emptyLabel.textColor = GiftSendPanelStyle.empty
        emptyLabel.font = GiftSendPanelTypography.emptyFont
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        backgroundView.addSubview(emptyLabel)

        dimmingControl.snp.makeConstraints { make in make.edges.equalToSuperview() }

        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            self.backgroundHeightConstraint = make.height.equalTo(contentHeightAboveSafeArea).constraint
        }

        headerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(14)
            make.height.equalTo(32)
        }

        titleLabel.snp.makeConstraints { make in make.center.equalToSuperview() }

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

        receiverChip.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(headerView.snp.bottom).offset(4)
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
            receiverChipHeightConstraint = make.height.equalTo(0).constraint
        }

        receiverLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
        }

        receiverCloseView.snp.makeConstraints { make in
            make.leading.equalTo(receiverLabel.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
            make.size.equalTo(CGSize(width: 8, height: 8))
        }

        categoryTabs.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(receiverChip.snp.bottom).offset(6)
            make.height.equalTo(32)
        }

        contentPager.snp.makeConstraints { make in
            make.leading.trailing.equalTo(backgroundView)
            make.top.equalTo(categoryTabs.snp.bottom).offset(10)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-20)
        }

        loadingIndicator.snp.makeConstraints { make in make.center.equalTo(contentPager) }

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
            page.onCellTapped = { [weak self] gift in self?.handleCellTapped(gift) }
            page.onComboSend = { [weak self] gift in self?.send(gift, count: 1) }
            page.onComboExpired = { [weak self] in self?.handleComboExpired() }
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
        if comboGiftID != nil { comboGiftID = nil }
        if selectedGiftID == gift.id {
            // Second tap on the already-selected gift: enter combo.
            // For advanced gifts (with an animation resourceURL), the panel yields
            // to a screen-level floating combo button owned by the host, matching
            // the reference web behavior.
            if gift.resourceURL != nil {
                selectedGiftID = nil
                applySelectionToPages()
                startFloatingCombo(with: gift)
                hidePanel()
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

    @objc private func tapReceiverChip() { setReceiver(userID: nil, name: nil) }

    private func handleComboExpired() {
        guard let gid = comboGiftID else { return }
        comboGiftID = nil
        selectedGiftID = gid
        applySelectionToPages()
    }

    private func endCombo() { comboGiftID = nil }

    private func applySelectionToPages() {
        let state: GiftGridPageView.SelectionState
        if let combo = comboGiftID {
            state = .combo(combo)
        } else if let selected = selectedGiftID {
            state = .selected(selected)
        } else {
            state = .none
        }
        for page in pageViews { page.setSelection(state) }
    }

    private func allGifts() -> [GiftItem] { categories.flatMap { $0.gifts } }
}

extension GiftSendPanelView: UIScrollViewDelegate {
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
private enum GiftSendPanelStyle {
    static let title: UIColor = UIColor.white.withAlphaComponent(0.94)
    static let balance: UIColor = UIColor.white.withAlphaComponent(0.82)
    static let loading: UIColor = UIColor.white.withAlphaComponent(0.7)
    static let empty: UIColor = UIColor.white.withAlphaComponent(0.5)
}

private enum GiftSendPanelTypography {
    static let titleFont: UIFont = UIFont.systemFont(ofSize: 16, weight: .bold)
    static let balanceFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    static let emptyFont: UIFont = UIFont.systemFont(ofSize: 14, weight: .regular)
}

// MARK: - Category tabs

private final class GiftCategoryTabsView: UIView {
    var onSelect: ((Int) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var buttons: [UIButton] = []
    private var underlineViews: [UIView] = []
    private var underlineGradients: [CAGradientLayer] = []
    private var selectedIndex: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in make.edges.equalToSuperview() }

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.spacing = 24
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 17, bottom: 0, right: 17)
        stackView.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(scrollView)
        }
    }

    func setCategories(_ names: [String]) {
        buttons.forEach { $0.removeFromSuperview() }
        underlineViews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        underlineViews.removeAll()
        underlineGradients.removeAll()
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, name) in names.enumerated() {
            let container = UIView()

            let button = UIButton(type: .custom)
            button.setTitle(name, for: .normal)
            button.titleLabel?.font = GiftCategoryTabsViewTypography.buttonFont
            button.tag = index
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 1)
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            container.addSubview(button)

            let underline = UIView()
            underline.isHidden = true
            let gradient = CAGradientLayer()
            gradient.colors = [GiftPanelStyle.blue.cgColor, GiftPanelStyle.deepBlue.cgColor]
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            gradient.cornerRadius = 1
            underline.layer.addSublayer(gradient)
            container.addSubview(underline)

            button.snp.makeConstraints { make in make.edges.equalToSuperview() }

            underline.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(6)
                make.trailing.equalToSuperview().offset(-6)
                make.bottom.equalToSuperview()
                make.height.equalTo(2)
            }

            stackView.addArrangedSubview(container)
            buttons.append(button)
            underlineViews.append(underline)
            underlineGradients.append(gradient)
        }

        if selectedIndex >= names.count { selectedIndex = 0 }
        applySelection()
        setNeedsLayout()
        layoutIfNeeded()
    }

    func setSelectedIndex(_ index: Int, animated: Bool) {
        guard buttons.indices.contains(index) else { return }
        if index == selectedIndex {
            applySelection()
            return
        }
        selectedIndex = index
        applySelection()
        scrollButtonToVisible(at: index, animated: animated)
    }

    @objc private func tabTapped(_ sender: UIButton) {
        let index = sender.tag
        guard buttons.indices.contains(index) else { return }
        if index != selectedIndex {
            selectedIndex = index
            applySelection()
            scrollButtonToVisible(at: index, animated: true)
        }
        onSelect?(index)
    }

    private func applySelection() {
        for (index, button) in buttons.enumerated() {
            let selected = index == selectedIndex
            button.setTitleColor(selected ? UIColor.white : UIColor.white.withAlphaComponent(0.5), for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: selected ? .bold : .regular)
            underlineViews[index].isHidden = !selected
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (index, underline) in underlineViews.enumerated() {
            guard underlineGradients.indices.contains(index) else { continue }
            underlineGradients[index].frame = underline.bounds
        }
    }

    private func scrollButtonToVisible(at index: Int, animated: Bool) {
        guard buttons.indices.contains(index) else { return }
        let button = buttons[index]
        let frame = button.superview?.convert(button.frame, to: scrollView) ?? .zero
        let visibleRect = CGRect(
            x: scrollView.contentOffset.x, y: 0, width: scrollView.bounds.width, height: scrollView.bounds.height)
        if !visibleRect.contains(frame) {
            scrollView.scrollRectToVisible(frame.insetBy(dx: -16, dy: 0), animated: animated)
        }
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum GiftCategoryTabsViewTypography {
    static let buttonFont: UIFont = UIFont.systemFont(ofSize: 14, weight: .regular)
}

enum GiftPanelStyle {
    static let blue: UIColor = UIColor(red: 74 / 255.0, green: 158 / 255.0, blue: 255 / 255.0, alpha: 1)
    static let deepBlue: UIColor = UIColor(red: 0 / 255.0, green: 82 / 255.0, blue: 217 / 255.0, alpha: 1)
    static let coin: UIColor = UIColor(red: 1.0, green: 0.792, blue: 0.298, alpha: 1)
}

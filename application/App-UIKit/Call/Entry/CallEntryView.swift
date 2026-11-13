import SnapKit
import TUICallKit_Swift
import UIKit

final class CallEntryView: UIView {

    var onFriendsTap: (() -> Void)?
    var onMoreSettingsTap: (() -> Void)?
    var onStartCallTap: (() -> Void)?

    private let state = CallEntryState.shared

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    private let idInput = TokenTextField()
    private let tokenListView = TokenFlowView()
    private let remainLabel = UILabel()
    private let mediaSegment = CallAccessSegment(items: [])
    private let resolutionSegment = CallAccessSegment(items: [])
    private let resolutionRow = UIView()
    private var resolutionDivider = UIView()
    private let captionToggle = CallAccessToggle(style: .caption)
    private let callButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupBindings()
        reloadFromState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reloadFromState() {
        renderTokens()
        captionToggle.isOn = state.captionOn
        mediaSegment.select(index: state.media == .video ? 0 : 1)
        resolutionSegment.select(index: CallEntryState.Resolution.allCases.firstIndex(of: state.resolution) ?? 0)
        let isAudio = state.media == .audio
        resolutionRow.isHidden = isAudio
        resolutionDivider.isHidden = isAudio
    }

    @discardableResult
    func commitPendingInput(isForCall: Bool) -> Bool {
        let parsed = CallEntryState.parseIDs(idInput.text ?? "")
        guard !parsed.isEmpty else { return true }
        var next = state.userIDs
        var seen = Set(next.map { $0.lowercased() })
        for id in parsed where !seen.contains(id.lowercased()) {
            seen.insert(id.lowercased())
            next.append(id)
        }
        if next.count > CallEntryState.maxCalleeIDs {
            CallAccessToast.show(isForCall ? CallAccessText.callTooManyNoDial : CallAccessText.callTooMany)
            return false
        }
        state.userIDs = next
        idInput.text = ""
        renderTokens()
        return true
    }

    func setCallButtonEnabled(_ enabled: Bool) {
        callButton.isEnabled = enabled
    }

    // MARK: - Token list

    private func renderTokens() {
        tokenListView.setTokens(state.userIDs) { [weak self] id in
            self?.removeToken(id)
        }
        let remaining = CallEntryState.maxCalleeIDs - state.userIDs.count
        let text = NSMutableAttributedString(
            string: CallAccessText.entryRemainPrefix,
            attributes: [.foregroundColor: CallAccessTheme.text3]
        )
        text.append(NSAttributedString(
            string: "\(remaining)",
            attributes: [.foregroundColor: CallAccessTheme.brand]
        ))
        text.append(NSAttributedString(
            string: CallAccessText.entryRemainSuffix,
            attributes: [.foregroundColor: CallAccessTheme.text3]
        ))
        remainLabel.attributedText = text
        idInput.attributedPlaceholder = NSAttributedString(
            string: remaining <= 0 ? CallAccessText.entryIDPlaceholderFull : CallAccessText.entryUserIDPlaceholder,
            attributes: [.foregroundColor: CallAccessTheme.text4]
        )
    }

    private func removeToken(_ id: String) {
        state.userIDs = state.userIDs.filter { $0 != id }
        renderTokens()
    }

    // MARK: - Layout

    private func setupViews() {
        backgroundColor = CallAccessTheme.pageBackground

        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
        }

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }

        stackView.axis = .vertical
        stackView.spacing = 10
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
        }

        stackView.addArrangedSubview(makeMainCard())
        stackView.addArrangedSubview(makeGapWithLine())
        stackView.addArrangedSubview(makeSettingsCard())

        let bottomBar = UIView()
        bottomBar.addSubview(callButton)
        callButton.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 6, right: 16))
            make.height.equalTo(50)
        }
        callButton.setTitle(CallAccessText.entryStartCall, for: .normal)
        callButton.setTitleColor(.white, for: .normal)
        callButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        callButton.layer.cornerRadius = 12
        callButton.clipsToBounds = true
        callButton.setBackgroundImage(UIColor.solidImage(CallAccessTheme.brand), for: .normal)
        callButton.setBackgroundImage(UIColor.solidImage(CallAccessTheme.brandHover), for: .highlighted)
        callButton.setBackgroundImage(UIColor.solidImage(CallAccessTheme.ctaDisabled), for: .disabled)
        addSubview(bottomBar)
        bottomBar.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBlankTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = CallAccessTheme.card
        card.layer.cornerRadius = 12
        return card
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = CallAccessTheme.line
        divider.snp.makeConstraints { make in
            make.height.equalTo(CallAccessTheme.hairline)
        }
        return divider
    }

    private func makeRowLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15)
        label.textColor = CallAccessTheme.text
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }

    private func makeChevron() -> UIImageView {
        let imageView = UIImageView(image: UIImage(named: "callkit_icon_chevron"))
        imageView.tintColor = CallAccessTheme.arrow
        imageView.contentMode = .scaleAspectFit
        imageView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }
        return imageView
    }

    private func makeGapWithLine() -> UIView {
        let container = UIView()
        let line = UIView()
        line.backgroundColor = CallAccessTheme.line
        container.addSubview(line)
        line.snp.makeConstraints { make in
            make.leading.trailing.centerY.equalToSuperview()
            make.height.equalTo(CallAccessTheme.hairline)
        }
        container.snp.makeConstraints { make in
            make.height.equalTo(14)
        }
        return container
    }

    private func makeMainCard() -> UIView {
        let card = makeCard()
        let cardStack = UIStackView()
        cardStack.axis = .vertical
        card.addSubview(cardStack)
        cardStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
        }

        cardStack.addArrangedSubview(makeIDBlock())
        let dividerContainer = UIView()
        let divider = makeDivider()
        dividerContainer.addSubview(divider)
        divider.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.leading.trailing.bottom.equalToSuperview()
        }
        dividerContainer.snp.makeConstraints { make in
            make.height.equalTo(4 + CallAccessTheme.hairline)
        }
        cardStack.addArrangedSubview(dividerContainer)
        cardStack.addArrangedSubview(makeMediaRow())
        cardStack.addArrangedSubview(makeDivider())
        cardStack.addArrangedSubview(makeCaptionRow())

        resolutionSegment.configure(
            items: CallEntryState.Resolution.allCases.map(\.displayName),
            fontSize: 12,
            width: 232
        )
        let resolutionStack = UIStackView(arrangedSubviews: [makeRowLabel(CallAccessText.entryResolution), resolutionSegment])
        resolutionStack.axis = .horizontal
        resolutionStack.alignment = .center
        resolutionStack.distribution = .equalSpacing
        resolutionRow.addSubview(resolutionStack)
        resolutionStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 0, bottom: 13, right: 0))
        }
        resolutionDivider = makeDivider()
        cardStack.addArrangedSubview(resolutionDivider)
        cardStack.addArrangedSubview(resolutionRow)
        return card
    }

    /// `.g-row--ids`: label row + bordered input box + always-visible token area + footer row.
    private func makeIDBlock() -> UIView {
        let block = UIView()

        let headLabel = makeRowLabel(CallAccessText.entryUserID)
        block.addSubview(headLabel)
        headLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview()
        }

        // .g-id-input: 1px #E3E6EB border, radius 10, height 44, padding 0 12, no fill
        let inputBox = UIView()
        inputBox.layer.borderWidth = 1
        inputBox.layer.borderColor = UIColor(hex: 0xE3E6EB).cgColor
        inputBox.layer.cornerRadius = 10
        block.addSubview(inputBox)
        inputBox.snp.makeConstraints { make in
            make.top.equalTo(headLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
        }

        idInput.font = .systemFont(ofSize: 15)
        idInput.textColor = CallAccessTheme.text
        idInput.autocapitalizationType = .none
        idInput.autocorrectionType = .no
        idInput.returnKeyType = .done
        idInput.onDeleteBackward = { [weak self] in
            guard let self, (self.idInput.text ?? "").isEmpty, let last = self.state.userIDs.last else { return }
            self.removeToken(last)
        }
        inputBox.addSubview(idInput)
        idInput.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.height.equalTo(32)
        }

        let addButton = UIButton(type: .system)
        addButton.setTitle(CallAccessText.entryAdd, for: .normal)
        addButton.setTitleColor(CallAccessTheme.brand, for: .normal)
        addButton.setTitleColor(CallAccessTheme.brandHover, for: .highlighted)
        addButton.titleLabel?.font = .systemFont(ofSize: 13)
        addButton.layer.borderWidth = 1
        addButton.layer.borderColor = CallAccessTheme.brand.cgColor
        addButton.layer.cornerRadius = 8
        addButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        idInput.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addButton.addTarget(self, action: #selector(handleAddTap), for: .touchUpInside)
        inputBox.addSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.height.equalTo(28)
            make.leading.equalTo(idInput.snp.trailing).offset(10)
        }

        // Tapping blank space inside the box focuses the input (demo: delegated on .g-row--ids)
        let boxTap = UITapGestureRecognizer(target: self, action: #selector(handleBoxTap))
        boxTap.cancelsTouchesInView = false
        inputBox.addGestureRecognizer(boxTap)

        // .g-token-list: grey capsule area, always visible, min 3 rows (108)
        let tokenArea = UIView()
        tokenArea.backgroundColor = CallAccessTheme.pageBackground
        tokenArea.layer.cornerRadius = 10
        tokenArea.addSubview(tokenListView)
        tokenListView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        }
        block.addSubview(tokenArea)
        tokenArea.snp.makeConstraints { make in
            make.top.equalTo(inputBox.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
        }

        // .g-ids-foot: remaining count (left) + friend picker button (right), margin-top 10
        remainLabel.font = .systemFont(ofSize: 12)
        let pickButton = UIButton(type: .system)
        pickButton.setTitle(CallAccessText.entryPickFromFriends, for: .normal)
        pickButton.setTitleColor(CallAccessTheme.brand, for: .normal)
        pickButton.setTitleColor(CallAccessTheme.brandHover, for: .highlighted)
        pickButton.titleLabel?.font = .systemFont(ofSize: 13)
        pickButton.layer.cornerRadius = 8
        pickButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        pickButton.addAction(UIAction { [weak self] _ in self?.onFriendsTap?() }, for: .touchUpInside)
        pickButton.snp.makeConstraints { make in
            make.height.equalTo(28)
        }

        let footRow = UIStackView(arrangedSubviews: [remainLabel, pickButton])
        footRow.axis = .horizontal
        footRow.alignment = .center
        footRow.distribution = .equalSpacing
        block.addSubview(footRow)
        footRow.snp.makeConstraints { make in
            make.top.equalTo(tokenArea.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-16)
        }
        return block
    }

    private func makeMediaRow() -> UIView {
        mediaSegment.configure(items: [CallAccessText.entryVideoCall, CallAccessText.entryAudioCall], fontSize: 13, width: 178)
        let mediaRow = UIStackView(arrangedSubviews: [makeRowLabel(CallAccessText.entryMediaType), mediaSegment])
        mediaRow.axis = .horizontal
        mediaRow.alignment = .center
        mediaRow.distribution = .equalSpacing
        mediaRow.snp.makeConstraints { make in
            make.height.equalTo(56)
        }
        return mediaRow
    }

    private func makeCaptionRow() -> UIView {
        let titleLabel = makeRowLabel(CallAccessText.entryCaption)
        let subtitleLabel = UILabel()
        subtitleLabel.text = CallAccessText.captionSwitchCopy
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = CallAccessTheme.text4
        subtitleLabel.numberOfLines = 1
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.7

        let textColumn = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textColumn.axis = .vertical
        textColumn.spacing = 3
        textColumn.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)

        captionToggle.onChange = { isOn in
            self.state.captionOn = isOn
            TUICallKit.createInstance().enableAITranscriber(enable: isOn)
        }

        let row = UIStackView(arrangedSubviews: [textColumn, captionToggle])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .fill
        row.spacing = 12
        captionToggle.setContentHuggingPriority(.required, for: .horizontal)
        captionToggle.setContentCompressionResistancePriority(.required, for: .horizontal)

        let container = UIView()
        container.addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 9, left: 0, bottom: 9, right: 0))
        }
        return container
    }

    private func makeSettingsCard() -> UIView {
        let card = makeCard()
        let label = makeRowLabel(CallAccessText.entryMoreSettings)
        let chevron = makeChevron()
        let row = UIStackView(arrangedSubviews: [label, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        let control = CallAccessTapRow()
        control.addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
            make.height.equalTo(52)
        }
        control.onTap = { [weak self] in self?.onMoreSettingsTap?() }
        card.addSubview(control)
        control.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        return card
    }

    private func setupBindings() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardFrameChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        mediaSegment.onSelect = { [weak self] index in
            self?.state.media = index == 0 ? .video : .audio
            self?.reloadFromState()
        }
        resolutionSegment.onSelect = { [weak self] index in
            self?.state.resolution = CallEntryState.Resolution.allCases[index]
        }
        callButton.addAction(UIAction { [weak self] _ in self?.onStartCallTap?() }, for: .touchUpInside)
        idInput.addTarget(self, action: #selector(handleIDChanged), for: .editingChanged)
        idInput.addTarget(self, action: #selector(handleIDEditingEnd), for: .editingDidEnd)
        idInput.addTarget(self, action: #selector(handleIDEditingEnd), for: .editingDidEndOnExit)
    }

    @objc private func handleIDChanged() {
        if let text = idInput.text, text.count > 32 {
            idInput.text = String(text.prefix(32))
        }
        if CallEntryState.containsSeparator(idInput.text ?? "") {
            commitPendingInput(isForCall: false)
        }
    }

    @objc private func handleIDEditingEnd() {
        commitPendingInput(isForCall: false)
    }

    @objc private func handleAddTap() {
        commitPendingInput(isForCall: false)
        idInput.becomeFirstResponder()
    }

    @objc private func handleBoxTap() {
        idInput.becomeFirstResponder()
    }

    @objc private func handleBlankTap() {
        endEditing(true)
    }

    @objc private func handleKeyboardFrameChange(_ notification: Notification) {
        guard let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let overlap = max(0, bounds.maxY - convert(frame, from: nil).minY)
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }
}

extension CallEntryView: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Let token × buttons and the friend button handle their own taps
        var view = touch.view
        while let current = view {
            if current is UIControl || current is UITextField { return false }
            view = current.superview
        }
        return true
    }
}

// MARK: - Token input

/// Text field that reports backward-deletes on empty text (used to remove the last token).
private final class TokenTextField: UITextField {

    var onDeleteBackward: (() -> Void)?

    override func deleteBackward() {
        let wasEmpty = (text ?? "").isEmpty
        super.deleteBackward()
        if wasEmpty {
            onDeleteBackward?()
        }
    }
}

// MARK: - Token capsule

/// `.g-token`: brand-soft capsule, 24 high, radius 6, 13pt brand text, × button on the right.
private final class TokenCapsuleView: UIView {

    init(id: String, onRemove: @escaping (String) -> Void) {
        super.init(frame: .zero)
        backgroundColor = CallAccessTheme.brandSoft
        layer.cornerRadius = 6

        let label = UILabel()
        label.text = id
        label.font = .systemFont(ofSize: 13)
        label.textColor = CallAccessTheme.brand
        label.lineBreakMode = .byTruncatingTail

        let removeButton = UIButton(type: .system)
        removeButton.setTitle("×", for: .normal)
        removeButton.setTitleColor(CallAccessTheme.brand.withAlphaComponent(0.65), for: .normal)
        removeButton.titleLabel?.font = .systemFont(ofSize: 15)
        removeButton.addAction(UIAction { _ in onRemove(id) }, for: .touchUpInside)

        addSubview(label)
        addSubview(removeButton)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(104)
        }
        removeButton.snp.makeConstraints { make in
            make.leading.equalTo(label.snp.trailing).offset(2)
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        snp.makeConstraints { make in
            make.height.equalTo(24)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Flow container

/// `.g-token-list` content: lays tokens out left to right, wrapping on overflow.
/// Grows with its content; the capsule area keeps a 108pt floor (3 rows) via constraints.
private final class TokenFlowView: UIView {

    private let spacing: CGFloat = 8

    override init(frame: CGRect) {
        super.init(frame: frame)
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(88)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTokens(_ ids: [String], onRemove: @escaping (String) -> Void) {
        subviews.forEach { $0.removeFromSuperview() }
        for id in ids {
            addSubview(TokenCapsuleView(id: id, onRemove: onRemove))
        }
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: contentHeight(forWidth: bounds.width))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutTokens()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: max(88, contentHeight(forWidth: size.width)))
    }

    private func contentHeight(forWidth width: CGFloat) -> CGFloat {
        guard width > 0, !subviews.isEmpty else { return 88 }
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var height: CGFloat = 0
        for token in subviews {
            let size = token.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x > 0, x + size.width > width {
                height += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return max(88, height + rowHeight)
    }

    private func layoutTokens() {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for token in subviews {
            let size = token.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            if x > 0, x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            token.frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Segmented control (.g-seg)

/// `.g-seg`: grey track (radius 9, 2pt padding), white selected item with brand text and shadow.
final class CallAccessSegment: UIView {

    var onSelect: ((Int) -> Void)?

    private let stackView = UIStackView()
    private var buttons: [UIButton] = []
    private var selectedIndex = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = CallAccessTheme.pageBackground
        layer.cornerRadius = 9
        stackView.axis = .horizontal
        stackView.spacing = 2
        stackView.distribution = .fillEqually
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(2)
            make.height.equalTo(28)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init(items: [String]) {
        self.init(frame: .zero)
        if !items.isEmpty {
            configure(items: items, fontSize: 13, width: nil)
        }
    }

    func configure(items: [String], fontSize: CGFloat, width: CGFloat?) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = items.enumerated().map { index, title in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: fontSize)
            button.layer.cornerRadius = 7
            button.tag = index
            button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            return button
        }
        if let width {
            snp.makeConstraints { make in
                make.width.equalTo(width)
            }
        }
        select(index: min(selectedIndex, max(items.count - 1, 0)))
    }

    func select(index: Int) {
        selectedIndex = index
        for (i, button) in buttons.enumerated() {
            let selected = i == index
            button.backgroundColor = selected ? .white : .clear
            button.setTitleColor(selected ? CallAccessTheme.brand : CallAccessTheme.text2, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: button.titleLabel?.font.pointSize ?? 13,
                                                  weight: selected ? .semibold : .regular)
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = selected ? 0.08 : 0
            button.layer.shadowOffset = CGSize(width: 0, height: 1)
            button.layer.shadowRadius = 3
        }
    }

    @objc private func handleTap(_ sender: UIButton) {
        select(index: sender.tag)
        onSelect?(sender.tag)
    }
}

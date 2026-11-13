import AtomicXCore
import Kingfisher
import SnapKit
import TUICallKit_Swift
import UIKit

final class CallSettingsView: UIView {


    private let state = CallEntryState.shared
    private let facade = TUICallKit.createInstance()

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let avatarImageView = UIImageView()
    private let nicknameInput = UITextField()
    private var nicknameHint = UILabel()

    private let roomIDInput = UITextField()
    private var roomIDHint = UILabel()
    private let timeoutInput = UITextField()
    private var timeoutHint = UILabel()
    private let extendedInfoInput = UITextField()
    private var extendedInfoHint = UILabel()

    private let advancedCard = UIView()
    private let advancedChevron = UIImageView()

    private var currentAvatarURL: String = ""
    private var currentNickname: String = ""

    // HTML: avatar choices are the 24 cloud presets user_avatar1..24.
    private static let presetAvatarURLs: [String] = (1...24).map {
        "https://liteav.sdk.qcloud.com/app/res/picture/voiceroom/avatar/user_avatar\($0).png"
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        reloadFromState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateProfile(_ profile: UserProfile?) {
        currentNickname = profile?.nickname?.isEmpty == false ? profile!.nickname! : (profile?.userID ?? "")
        nicknameInput.text = currentNickname
        currentAvatarURL = profile?.avatarURL ?? ""
        if let url = URL(string: currentAvatarURL), !currentAvatarURL.isEmpty {
            avatarImageView.kf.setImage(with: url)
        } else {
            avatarImageView.image = nil
        }
    }

    private func reloadFromState() {
        roomIDInput.text = state.roomID.isEmpty ? CallAccessText.settingsRoomAutoAssign : state.roomID
        timeoutInput.text = "\(state.timeoutSeconds)"
        extendedInfoInput.text = state.extendedInfo.isEmpty ? CallAccessText.settingsExtendedInfoEmpty : state.extendedInfo
    }

    // MARK: - Layout

    private func setupViews() {
        backgroundColor = CallAccessTheme.pageBackground

        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }

        contentStack.axis = .vertical
        contentStack.spacing = 10
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide).inset(UIEdgeInsets(top: 10, left: 16, bottom: 24, right: 16))
            make.width.equalTo(scrollView.frameLayoutGuide).offset(-32)
        }

        contentStack.addArrangedSubview(makeGroupTitle(CallAccessText.settingsProfile))
        contentStack.addArrangedSubview(makeProfileCard())
        contentStack.addArrangedSubview(makeGroupTitle(CallAccessText.settingsIncoming))
        contentStack.addArrangedSubview(makeIncomingCard())
        contentStack.addArrangedSubview(makeGroupTitle(CallAccessText.settingsCallUI))
        contentStack.addArrangedSubview(makeCallUICard())
        contentStack.addArrangedSubview(makeAdvancedToggle())
        contentStack.addArrangedSubview(advancedCard)
        makeAdvancedCard()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBlankTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardFrameChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    private func makeGroupTitle(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12)
        label.textColor = CallAccessTheme.text2
        return label
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
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
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

    private func makeHint(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 11)
        label.textColor = CallAccessTheme.text3
        label.isHidden = true
        label.snp.makeConstraints { make in
            make.height.equalTo(26)
        }
        return label
    }

    // MARK: Profile

    private func makeProfileCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
        }

        // Avatar row (56pt)
        avatarImageView.layer.cornerRadius = 17
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = CallAccessTheme.brandSoft
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.snp.makeConstraints { make in
            make.size.equalTo(34)
        }
        let avatarValueGroup = UIStackView(arrangedSubviews: [avatarImageView, makeChevron()])
        avatarValueGroup.axis = .horizontal
        avatarValueGroup.spacing = 4
        avatarValueGroup.alignment = .center
        let avatarRow = makeTappableRow(label: CallAccessText.settingsAvatar, trailing: avatarValueGroup, height: 56) { [weak self] in
            guard let self else { return }
            dismissActiveEditor()
            openAvatarPicker()
        }
        stack.addArrangedSubview(avatarRow)
        stack.addArrangedSubview(makeDivider())

        nicknameInput.borderStyle = .none
        nicknameInput.font = .systemFont(ofSize: 15)
        nicknameInput.textColor = CallAccessTheme.text2
        nicknameInput.textAlignment = .right
        nicknameInput.isEnabled = false
        nicknameInput.returnKeyType = .done
        nicknameHint = makeHint(CallAccessText.settingsNicknameHint)

        let nicknameValueGroup = UIStackView(arrangedSubviews: [nicknameInput, makeChevron()])
        nicknameValueGroup.axis = .horizontal
        nicknameValueGroup.spacing = 4
        nicknameValueGroup.alignment = .center
        let nicknameRow = UIStackView(arrangedSubviews: [makeRowLabel(CallAccessText.settingsNickname), nicknameValueGroup])
        nicknameRow.axis = .horizontal
        nicknameRow.alignment = .center
        nicknameRow.spacing = 12
        nicknameRow.snp.makeConstraints { make in
            make.height.equalTo(52)
        }
        let nicknameControl = CallAccessTapRow()
        nicknameControl.addSubview(nicknameRow)
        nicknameRow.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        nicknameControl.onTap = { [weak self] in self?.beginNicknameEditing() }
        stack.addArrangedSubview(nicknameControl)
        stack.addArrangedSubview(nicknameHint)

        nicknameInput.addTarget(self, action: #selector(handleNicknameInput), for: .editingChanged)
        nicknameInput.addTarget(self, action: #selector(commitNickname), for: .editingDidEnd)
        nicknameInput.addTarget(self, action: #selector(commitNickname), for: .editingDidEndOnExit)
        nicknameInput.delegate = self
        return card
    }

    // MARK: Incoming call

    private func makeIncomingCard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
        }

        // Ringtone row: only the system default exists until ringtone assets land in the component.
        let ringtoneValueLabel = UILabel()
        ringtoneValueLabel.text = state.ringtoneLabel
        ringtoneValueLabel.font = .systemFont(ofSize: 15)
        ringtoneValueLabel.textColor = CallAccessTheme.text2
        let ringtoneValueGroup = UIStackView(arrangedSubviews: [ringtoneValueLabel, makeChevron()])
        ringtoneValueGroup.axis = .horizontal
        ringtoneValueGroup.spacing = 4
        ringtoneValueGroup.alignment = .center
        stack.addArrangedSubview(makeTappableRow(label: CallAccessText.settingsRingtone, trailing: ringtoneValueGroup, height: 52) { [weak self] in
            guard let self else { return }
            dismissActiveEditor()
            openRingtonePicker(valueLabel: ringtoneValueLabel)
        })
        stack.addArrangedSubview(makeDivider())

        let muteToggle = CallAccessToggle()
        muteToggle.isOn = state.muteModeEnabled
        muteToggle.onChange = { [weak self] isOn in
            self?.dismissActiveEditor()
            self?.state.muteModeEnabled = isOn
            self?.facade.enableMuteMode(enable: isOn)
        }
        stack.addArrangedSubview(makeRow(label: CallAccessText.settingsMuteMode, trailing: muteToggle, height: 52))
        stack.addArrangedSubview(makeDivider())

        // Banner row with subtitle (tall 62pt)
        let bannerTitle = makeRowLabel(CallAccessText.settingsBanner)
        let bannerSubtitle = UILabel()
        bannerSubtitle.text = CallAccessText.settingsBannerCopy
        bannerSubtitle.font = .systemFont(ofSize: 11)
        bannerSubtitle.textColor = CallAccessTheme.text4
        let bannerText = UIStackView(arrangedSubviews: [bannerTitle, bannerSubtitle])
        bannerText.axis = .vertical
        bannerText.spacing = 3
        bannerText.alignment = .leading
        let bannerToggle = CallAccessToggle()
        bannerToggle.isOn = state.bannerOn
        bannerToggle.onChange = { [weak self] isOn in
            self?.dismissActiveEditor()
            self?.state.bannerOn = isOn
            self?.facade.enableIncomingBanner(enable: isOn)
        }
        let bannerRow = UIView()
        bannerRow.addSubview(bannerText)
        bannerRow.addSubview(bannerToggle)
        bannerText.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.equalTo(bannerToggle.snp.leading).offset(-12)
        }
        bannerToggle.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
        bannerRow.snp.makeConstraints { make in
            make.height.equalTo(62)
        }
        stack.addArrangedSubview(bannerRow)
        return card
    }

    // MARK: Call UI

    private func makeCallUICard() -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .vertical
        card.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
        }

        let floatToggle = CallAccessToggle()
        floatToggle.isOn = state.showFloatButton
        floatToggle.onChange = { [weak self] isOn in
            self?.dismissActiveEditor()
            self?.state.showFloatButton = isOn
            self?.facade.enableFloatWindow(enable: isOn)
        }
        stack.addArrangedSubview(makeRow(label: CallAccessText.settingsFloatButton, trailing: floatToggle, height: 52))
        stack.addArrangedSubview(makeDivider())

        let blurToggle = CallAccessToggle()
        blurToggle.isOn = state.blurBackgroundOn
        blurToggle.onChange = { [weak self] isOn in
            self?.dismissActiveEditor()
            self?.state.blurBackgroundOn = isOn
            self?.facade.enableVirtualBackground(enable: isOn)
        }
        stack.addArrangedSubview(makeRow(label: CallAccessText.settingsBlurBackground, trailing: blurToggle, height: 52))
        stack.addArrangedSubview(makeDivider())

        // 「高级美颜」label + amber Pro badge (.g-label--pro / .g-pro-badge), demo-only state.
        let proTitleStack = UIStackView(arrangedSubviews: [makeRowLabel(CallAccessText.settingsProBeauty), ProBadgeView()])
        proTitleStack.axis = .horizontal
        proTitleStack.alignment = .center
        proTitleStack.spacing = 8
        let proToggle = CallAccessToggle()
        proToggle.isOn = state.proBeautyOn
        proToggle.onChange = { [weak self] isOn in
            self?.dismissActiveEditor()
            self?.state.proBeautyOn = isOn
        }
        stack.addArrangedSubview(makeRow(label: "", customLeading: proTitleStack, trailing: proToggle, height: 52))
        return card
    }

    // MARK: Advanced (collapsible)

    private func makeAdvancedToggle() -> UIView {
        // .g-dev-toggle: left-aligned "text + 12px chevron" (gap 4), not a full-width row
        let label = UILabel()
        label.text = CallAccessText.settingsAdvanced
        label.font = .systemFont(ofSize: 12)
        label.textColor = CallAccessTheme.text2

        advancedChevron.image = UIImage(named: "callkit_icon_chevron")
        advancedChevron.tintColor = CallAccessTheme.arrow
        advancedChevron.contentMode = .scaleAspectFit
        advancedChevron.snp.makeConstraints { make in
            make.size.equalTo(12)
        }

        let row = UIStackView(arrangedSubviews: [label, advancedChevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 4

        let control = CallAccessTapRow()
        control.addSubview(row)
        row.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        control.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
        control.onTap = { [weak self] in
            guard let self else { return }
            dismissActiveEditor()
            toggleAdvanced()
        }
        return control
    }

    private func toggleAdvanced() {
        advancedCard.isHidden.toggle()
        UIView.animate(withDuration: 0.18) {
            self.advancedChevron.transform = self.advancedCard.isHidden ? .identity : CGAffineTransform(rotationAngle: .pi / 2)
        }
    }

    private func makeAdvancedCard() {
        advancedCard.isHidden = true
        advancedCard.backgroundColor = CallAccessTheme.card
        advancedCard.layer.cornerRadius = 12

        let stack = UIStackView()
        stack.axis = .vertical
        advancedCard.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14))
        }

        roomIDHint = makeHint(CallAccessText.settingsRoomIDHint)
        timeoutHint = makeHint(CallAccessText.settingsTimeoutHint)
        extendedInfoHint = makeHint(CallAccessText.settingsExtendedInfoHint)

        stack.addArrangedSubview(makeInlineEditorRow(
            title: CallAccessText.settingsRoomID, subtitle: CallAccessText.settingsRoomIDSub,
            input: roomIDInput, maxLength: 32
        ) { [weak self] in
            guard let self else { return }
            self.beginEditing(input: self.roomIDInput, hint: self.roomIDHint)
        })
        stack.addArrangedSubview(roomIDHint)
        stack.addArrangedSubview(makeDivider())

        stack.addArrangedSubview(makeInlineEditorRow(
            title: CallAccessText.settingsTimeout, subtitle: CallAccessText.settingsTimeoutSub,
            input: timeoutInput, maxLength: 3
        ) { [weak self] in
            guard let self else { return }
            self.beginEditing(input: self.timeoutInput, hint: self.timeoutHint)
        })
        stack.addArrangedSubview(timeoutHint)
        stack.addArrangedSubview(makeDivider())

        stack.addArrangedSubview(makeInlineEditorRow(
            title: CallAccessText.settingsExtendedInfo, subtitle: CallAccessText.settingsExtendedInfoSub,
            input: extendedInfoInput, maxLength: 64
        ) { [weak self] in
            guard let self else { return }
            self.beginEditing(input: self.extendedInfoInput, hint: self.extendedInfoHint)
        })
        stack.addArrangedSubview(extendedInfoHint)

        // Placeholders show while editing with an empty value (HTML: placeholder="自动分配" / "可留空", --text-4)
        let placeholderAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: CallAccessTheme.text4]
        roomIDInput.attributedPlaceholder = NSAttributedString(string: CallAccessText.settingsRoomAutoAssign, attributes: placeholderAttributes)
        timeoutInput.keyboardType = .numberPad

        roomIDInput.addTarget(self, action: #selector(commitRoomID), for: .editingDidEnd)
        roomIDInput.addTarget(self, action: #selector(commitRoomID), for: .editingDidEndOnExit)
        timeoutInput.addTarget(self, action: #selector(commitTimeout), for: .editingDidEnd)
        timeoutInput.addTarget(self, action: #selector(commitTimeout), for: .editingDidEndOnExit)
        extendedInfoInput.addTarget(self, action: #selector(commitExtendedInfo), for: .editingDidEnd)
        extendedInfoInput.addTarget(self, action: #selector(commitExtendedInfo), for: .editingDidEndOnExit)
        [roomIDInput, timeoutInput, extendedInfoInput].forEach {
            $0.addTarget(self, action: #selector(handleAdvancedInput(_:)), for: .editingChanged)
        }
        roomIDInput.delegate = self
        timeoutInput.delegate = self
        extendedInfoInput.delegate = self
    }

    // MARK: - Row helpers

    private func makeRow(label: String, customLeading: UIView? = nil, trailing: UIView, height: CGFloat) -> UIView {
        let leading = customLeading ?? makeRowLabel(label)
        let row = UIStackView(arrangedSubviews: [leading, trailing])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        row.snp.makeConstraints { make in
            make.height.equalTo(height)
        }
        return row
    }

    private func makeTappableRow(label: String, trailing: UIView, height: CGFloat, onTap: @escaping () -> Void) -> UIView {
        let row = makeRow(label: label, trailing: trailing, height: height)
        let control = UIControl()
        control.addSubview(row)
        row.isUserInteractionEnabled = false
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        control.addAction(UIAction { _ in onTap() }, for: .touchUpInside)
        return control
    }

    private func makeInlineEditorRow(
        title: String, subtitle: String,
        input: UITextField,
        maxLength: Int,
        onBeginEdit: @escaping () -> Void
    ) -> UIView {
        let titleLabel = makeRowLabel(title)
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = CallAccessTheme.text4
        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 3
        titleStack.alignment = .leading
        titleStack.setContentHuggingPriority(.required, for: .horizontal)
        titleStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        input.borderStyle = .none
        input.font = .systemFont(ofSize: 15)
        input.textColor = CallAccessTheme.text2
        input.textAlignment = .right
        input.isEnabled = false
        input.returnKeyType = .done

        let valueGroup = UIStackView(arrangedSubviews: [input, makeChevron()])
        valueGroup.axis = .horizontal
        valueGroup.spacing = 4
        valueGroup.alignment = .center

        let row = UIStackView(arrangedSubviews: [titleStack, valueGroup])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.snp.makeConstraints { make in
            make.height.equalTo(62)
        }

        let control = CallAccessTapRow()
        control.addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        control.onTap = onBeginEdit
        return control
    }

    // MARK: - Inline editing behavior

    private var activeEditingHint: UILabel?

    private func beginEditing(input: UITextField, hint: UILabel) {
        guard !input.isEnabled else { return }
        if input.text == CallAccessText.settingsRoomAutoAssign || input.text == CallAccessText.settingsExtendedInfoEmpty {
            input.text = ""
        }
        input.isEnabled = true
        input.textColor = CallAccessTheme.text
        hint.isHidden = false
        hint.textColor = CallAccessTheme.text3
        input.becomeFirstResponder()
        input.selectAll(nil)
        activeEditingHint = hint
        scrollHintIntoView(hint, animated: true)
    }

    private func beginNicknameEditing() {
        beginEditing(input: nicknameInput, hint: nicknameHint)
    }

    private func endEditing(input: UITextField, hint: UILabel) {
        input.isEnabled = false
        input.textColor = CallAccessTheme.text2
        hint.isHidden = true
        hint.textColor = CallAccessTheme.text3
        if activeEditingHint === hint { activeEditingHint = nil }
    }

    private func scrollHintIntoView(_ hint: UILabel, animated: Bool) {
        DispatchQueue.main.async { [weak self, weak hint] in
            guard let self, let hint, !hint.isHidden else { return }
            self.scrollView.layoutIfNeeded()
            self.scrollView.scrollRectToVisible(hint.convert(hint.bounds, to: self.scrollView).insetBy(dx: 0, dy: -8), animated: animated)
        }
    }

    @objc private func handleNicknameInput() {
        // Demo: maxlength=24
        if let text = nicknameInput.text, text.count > 24 {
            nicknameInput.text = String(text.prefix(24))
        }
        nicknameHint.textColor = isValidNickname(nicknameInput.text ?? "") ? CallAccessTheme.text3 : CallAccessTheme.red
    }

    /// Demo maxlengths: room ID 32, timeout 3, extended info 64.
    @objc private func handleAdvancedInput(_ textField: UITextField) {
        let limit: Int
        switch textField {
        case roomIDInput: limit = 32
        case timeoutInput: limit = 3
        default: limit = 64
        }
        if let text = textField.text, text.count > limit {
            textField.text = String(text.prefix(limit))
        }
    }

    @objc private func commitNickname() {
        let value = (nicknameInput.text ?? "").trimmingCharacters(in: .whitespaces)
        if !value.isEmpty && isValidNickname(value), value != currentNickname {
            currentNickname = value
            facade.setSelfInfo(nickname: value, avatar: currentAvatarURL, completion: nil)
        } else {
            nicknameInput.text = currentNickname
        }
        endEditing(input: nicknameInput, hint: nicknameHint)
    }

    @objc private func commitRoomID() {
        let value = (roomIDInput.text ?? "").trimmingCharacters(in: .whitespaces)
        if value.isEmpty || isValidRoomID(value) {
            state.roomID = value
        }
        roomIDInput.text = state.roomID.isEmpty ? CallAccessText.settingsRoomAutoAssign : state.roomID
        endEditing(input: roomIDInput, hint: roomIDHint)
    }

    @objc private func commitTimeout() {
        let value = (timeoutInput.text ?? "").trimmingCharacters(in: .whitespaces)
        if let seconds = Int(value), (1...180).contains(seconds) {
            state.timeoutSeconds = seconds
        }
        timeoutInput.text = "\(state.timeoutSeconds)"
        endEditing(input: timeoutInput, hint: timeoutHint)
    }

    @objc private func commitExtendedInfo() {
        let value = extendedInfoInput.text ?? ""
        if value.count <= 64 {
            state.extendedInfo = value
        }
        extendedInfoInput.text = state.extendedInfo.isEmpty ? CallAccessText.settingsExtendedInfoEmpty : state.extendedInfo
        endEditing(input: extendedInfoInput, hint: extendedInfoHint)
    }

    private func isValidNickname(_ value: String) -> Bool {
        // Demo rule: 2-24 chars of Chinese / letters / digits.
        value.range(of: #"^[一-龥A-Za-z0-9]{2,24}$"#, options: .regularExpression) != nil
    }

    private func isValidRoomID(_ value: String) -> Bool {
        // Demo rule: digits only or letters only, not mixed, ≤ 32 chars.
        value.range(of: #"^(?:\d{1,32}|[A-Za-z]{1,32})$"#, options: .regularExpression) != nil
    }

    // MARK: - Pickers
    private func openAvatarPicker() {
        guard let host = nearestViewControllerView() else { return }

        // 统一抽屉口径：点选只换高亮，右上动作键落地；所选==当前=取消，不同=确定
        var picked = currentAvatarURL
        var cellUpdaters: [String: (Bool) -> Void] = [:]

        var sheet: CallAccessSheet!
        sheet = CallAccessSheet(title: CallAccessText.avatarPickerTitle, actionTitle: CallAccessText.sheetCancel, isCancelAction: true)
        // init 参数阶段 sheet 尚未赋值，weak 捕获必须后置接线才有效
        sheet.setOnAction { [weak self, weak sheet] in
            guard let self, let sheet else { return }
            if picked != self.currentAvatarURL {
                self.applyAvatar(picked)
            }
            sheet.dismiss()
        }
        // 弱捕获：cell 的 UIAction → syncAction 在视图树内，强捕获 sheet/self 会形成循环引用
        let syncAction: () -> Void = { [weak self, weak sheet] in
            guard let sheet else { return }
            let unchanged = picked == (self?.currentAvatarURL ?? picked)
            sheet.setAction(title: unchanged ? CallAccessText.sheetCancel : CallAccessText.sheetConfirm, isCancel: unchanged)
        }

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 16
        grid.layoutMargins = UIEdgeInsets(top: 12, left: 0, bottom: 6, right: 0)
        grid.isLayoutMarginsRelativeArrangement = true

        let columns = 4
        var rowStack: UIStackView?
        for (index, urlString) in Self.presetAvatarURLs.enumerated() {
            if index % columns == 0 {
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = 12
                row.distribution = .fillEqually
                grid.addArrangedSubview(row)
                rowStack = row
            }
            let (cell, updateSelection) = makeAvatarCell(urlString: urlString)
            cellUpdaters[urlString] = updateSelection
            updateSelection(urlString == picked)
            cell.addAction(UIAction { _ in
                if picked == urlString { return }   // 单选：重复点当前项不变
                cellUpdaters[picked]?(false)
                picked = urlString
                updateSelection(true)
                syncAction()
            }, for: .touchUpInside)
            rowStack?.addArrangedSubview(cell)
        }
        syncAction()
        sheet.setContent(grid)
        sheet.present(in: host)
    }

    private func makeAvatarCell(urlString: String) -> (UIControl, (Bool) -> Void) {
        let cell = UIControl()

        let avatar = UIImageView()
        avatar.layer.cornerRadius = 28
        avatar.clipsToBounds = true
        avatar.contentMode = .scaleAspectFill
        avatar.backgroundColor = CallAccessTheme.closeBackground
        avatar.isUserInteractionEnabled = false
        avatar.kf.setImage(with: URL(string: urlString))
        avatar.snp.makeConstraints { make in
            make.size.equalTo(56)
        }

        let badge = UILabel()
        badge.text = "✓"
        badge.textColor = .white
        badge.font = .systemFont(ofSize: 11)
        badge.textAlignment = .center
        badge.backgroundColor = CallAccessTheme.brand
        badge.layer.cornerRadius = 9
        badge.clipsToBounds = true
        badge.snp.makeConstraints { make in
            make.size.equalTo(18)
        }

        cell.addSubview(avatar)
        cell.addSubview(badge)
        avatar.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        badge.snp.makeConstraints { make in
            make.trailing.equalTo(avatar.snp.trailing).offset(4)
            make.bottom.equalTo(avatar.snp.bottom).offset(2)
        }
        cell.snp.makeConstraints { make in
            make.height.equalTo(60)
        }
        let updateSelection: (Bool) -> Void = { selected in
            avatar.layer.borderWidth = selected ? 2 : 0
            avatar.layer.borderColor = CallAccessTheme.brand.cgColor
            badge.isHidden = !selected
        }
        return (cell, updateSelection)
    }

    private func applyAvatar(_ urlString: String) {
        currentAvatarURL = urlString
        avatarImageView.kf.setImage(with: URL(string: urlString))
        facade.setSelfInfo(nickname: currentNickname, avatar: urlString, completion: nil)
        CallAccessToast.show(CallAccessText.settingsAvatarSetToast)
    }

    private func openRingtonePicker(valueLabel: UILabel) {
        guard let host = nearestViewControllerView() else { return }

        // 统一抽屉口径：点选只换高亮，右上动作键落地；所选==当前=取消，不同=确定
        let options: [(id: String, label: String)] = [
            ("", CallAccessText.settingsRingtoneDefault),
            (CallEntryState.builtinRingtoneName, CallEntryState.builtinRingtoneName),
        ]
        var picked = state.ringtone
        var rowUpdaters: [String: (Bool) -> Void] = [:]

        var sheet: CallAccessSheet!
        sheet = CallAccessSheet(title: CallAccessText.ringtonePickerTitle, actionTitle: CallAccessText.sheetCancel, isCancelAction: true)
        // init 参数阶段 sheet 尚未赋值，weak 捕获必须后置接线才有效
        sheet.setOnAction { [weak self, weak sheet] in
            guard let self, let sheet else { return }
            if picked != self.state.ringtone {
                self.applyRingtone(picked, valueLabel: valueLabel)
            }
            sheet.dismiss()
        }
        // 弱捕获：row 的 UIAction → syncAction 在视图树内，强捕获 sheet/self 会形成循环引用
        let syncAction: () -> Void = { [weak self, weak sheet] in
            guard let sheet else { return }
            let unchanged = picked == (self?.state.ringtone ?? picked)
            sheet.setAction(title: unchanged ? CallAccessText.sheetCancel : CallAccessText.sheetConfirm, isCancel: unchanged)
        }

        let stack = UIStackView()
        stack.axis = .vertical
        for (index, option) in options.enumerated() {
            let (row, updateSelection) = makeRingtoneRow(title: option.label, showsSeparator: index < options.count - 1)
            rowUpdaters[option.id] = updateSelection
            updateSelection(option.id == picked)
            row.addAction(UIAction { _ in
                if picked == option.id { return }
                rowUpdaters[picked]?(false)
                picked = option.id
                updateSelection(true)
                syncAction()
            }, for: .touchUpInside)
            stack.addArrangedSubview(row)
        }
        syncAction()
        sheet.setContent(stack)
        sheet.present(in: host)
    }

    private func makeRingtoneRow(title: String, showsSeparator: Bool) -> (UIControl, (Bool) -> Void) {
        let row = UIControl()
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15)
        let check = UILabel()
        check.text = "✓"
        check.font = .systemFont(ofSize: 15, weight: .bold)
        check.textColor = CallAccessTheme.brand
        let separator = UIView()
        separator.backgroundColor = CallAccessTheme.line
        separator.isHidden = !showsSeparator

        row.addSubview(label)
        row.addSubview(check)
        row.addSubview(separator)
        label.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(check.snp.leading).offset(-8)
        }
        check.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
        separator.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(CallAccessTheme.hairline)
        }
        row.snp.makeConstraints { make in
            make.height.equalTo(52)
        }
        let updateSelection: (Bool) -> Void = { selected in
            label.font = .systemFont(ofSize: 15, weight: selected ? .semibold : .regular)
            label.textColor = selected ? CallAccessTheme.brand : CallAccessTheme.text
            check.isHidden = !selected
        }
        return (row, updateSelection)
    }

    private func applyRingtone(_ id: String, valueLabel: UILabel) {
        if id.isEmpty {
            state.ringtone = ""
            facade.setCallingBell(filePath: "")
        } else {
            guard let path = Bundle.main.path(forResource: "phone_ringing", ofType: "mp3") else {
                CallAccessToast.show(String(format: CallAccessText.callFailed, "ringtone"))
                return
            }
            state.ringtone = id
            facade.setCallingBell(filePath: path)
        }
        valueLabel.text = state.ringtoneLabel
        CallAccessToast.show(String(format: CallAccessText.settingsRingtoneSetToast, state.ringtoneLabel))
    }

    private func nearestViewControllerView() -> UIView? {
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller.navigationController?.view ?? controller.view
            }
            responder = current.next
        }
        return nil
    }

    @objc private func handleBlankTap() {
        dismissActiveEditor()
    }

    private func dismissActiveEditor() {
        endEditing(true)
    }

    @objc private func handleKeyboardFrameChange(_ notification: Notification) {
        guard let frame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let overlap = max(0, bounds.maxY - convert(frame, from: nil).minY)
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
        if let hint = activeEditingHint {
            scrollHintIntoView(hint, animated: false)
        }
    }
}

extension CallSettingsView: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension CallSettingsView: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is CallAccessTapRow || current is UITextField || current is UIControl { return false }
            view = current.superview
        }
        return true
    }
}

/// .g-pro-badge: 22pt amber gradient pill with serif bold "Pro" (#3D2B04).
private final class ProBadgeView: UIView {

    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.colors = [UIColor(hex: 0xF9DA93).cgColor, UIColor(hex: 0xEFC463).cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(gradient, at: 0)
        layer.cornerRadius = 11
        layer.masksToBounds = true

        let label = UILabel()
        label.text = "Pro"
        label.font = UIFont(name: "TimesNewRomanPS-BoldMT", size: 13) ?? .systemFont(ofSize: 13, weight: .bold)
        label.textColor = UIColor(hex: 0x3D2B04)
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.center.equalToSuperview()
        }
        snp.makeConstraints { make in
            make.height.equalTo(22)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }
}

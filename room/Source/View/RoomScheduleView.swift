//
//  RoomScheduleView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/7/28.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore
import AtomicX
import Combine

public class RoomScheduleView: UIView, BaseView {
    
    public enum Mode {
        case create
        case edit(roomID: String)
    }
    
    private enum UpdateAction {
        case updateRoom(flag: ScheduleRoomOptions.ModifyFlag)
        case addAttendees([String])
        case removeAttendees([String])
    }
    
    // MARK: - Properties
    
    public weak var routerContext: RouterContext?
    
    public var onScheduled: ((RoomScheduleInfo) -> Void)?
    
    public var onUpdated: (() -> Void)?
    
    private var mode: Mode = .create
    
    private var originalRoomInfo: RoomInfo?
    
    private var scheduleOptions = ScheduleRoomOptions()
    
    private var isScheduling: Bool = false {
        didSet {
            scheduleButton.isEnabled = !isScheduling
            scheduleButton.alpha = isScheduling ? 0.5 : 1.0
        }
    }
    
    private var durationMinutes: Int = 30 {
        didSet { syncScheduleEndTime() }
    }
    
    private let roomType: RoomType = .standard
    
    private var timeZone: TimeZone = TimeZone.current
    
    private var selectedAttendees: [ContactInfo] = []
    
    private var cancellableSet = Set<AnyCancellable>()
    
    private var currentItems: [RoomScheduleMenuItem] = []
    
    private var valueViewByID: [RoomScheduleMenuID: UIView] = [:]
    
    private var rowByID: [RoomScheduleMenuID: UIStackView] = [:]
    
    private var idByTextField: [ObjectIdentifier: RoomScheduleMenuID] = [:]
    
    private var cardContainers: [RoomScheduleCardID: UIStackView] = [:]
    
    // MARK: - UI Components
    
    private lazy var backButtonContainerView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("back_arrow"), for: .normal)
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        makeLabel(.scheduleRoom, color: RoomColors.g2, weight: .medium)
    }()
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.keyboardDismissMode = .onDrag
        return sv
    }()
    
    private lazy var contentView: UIView = {
        let v = UIView()
        return v
    }()
    
    private lazy var cardsStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = RoomScheduleLayout.cardSpacing
        sv.alignment = .fill
        sv.distribution = .fill
        return sv
    }()
    
    private lazy var scheduleButton: UIButton = {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = RoomScheduleLayout.cardCornerRadius
        button.clipsToBounds = true
        button.backgroundColor = RoomColors.b1
        button.setTitle(.scheduleRoom, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        return button
    }()
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        let start = Date.roundedUpToNextFiveMinutes(from: Date())
        scheduleOptions.scheduleStartTime = Date.secondsSince1970(from: start)
        scheduleOptions.roomName = defaultRoomName()
        syncScheduleEndTime()
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
        subscribeLoginStore()
        registerKeyboardNotifications()
        renderMenuItems()
    }
    
    public convenience init(editing roomInfo: RoomInfo, timeZone: TimeZone = .current) {
        self.init(frame: .zero)
        mode = .edit(roomID: roomInfo.roomID)
        originalRoomInfo = roomInfo
        self.timeZone = timeZone
        
        scheduleOptions.roomName = roomInfo.roomName
        scheduleOptions.password = roomInfo.password ?? ""
        scheduleOptions.isAllMicrophoneDisabled = roomInfo.isAllMicrophoneDisabled
        scheduleOptions.isAllCameraDisabled = roomInfo.isAllCameraDisabled
        scheduleOptions.scheduleStartTime = roomInfo.scheduledStartTime
        let totalMinutes = max(1, (roomInfo.scheduledEndTime - roomInfo.scheduledStartTime) / 60)
        durationMinutes = totalMinutes
        selectedAttendees = roomInfo.scheduleAttendees.map { user in
            var contact = ContactInfo(userID: user.userID)
            contact.nickname = user.userName
            contact.avatarURL = user.avatarURL
            return contact
        }
        
        titleLabel.text = .editRoom
        scheduleButton.setTitle(.save, for: .normal)
        
        renderMenuItems()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - BaseView Implementation
    
    public func setupViews() {
        addSubview(backButtonContainerView)
        backButtonContainerView.addSubview(backButton)
        backButtonContainerView.addSubview(titleLabel)
        
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(cardsStackView)
        contentView.addSubview(scheduleButton)
        
        let cards: [RoomScheduleCardID] = [.info, .security, .control]
        for card in cards {
            let container = makeCardStackView()
            cardContainers[card] = container
            cardsStackView.addArrangedSubview(container)
        }
    }
    
    public func setupConstraints() {
        backButtonContainerView.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top)
                .offset(RoomScheduleLayout.navBarHeight)
        }
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(RoomScheduleLayout.horizontalPadding)
            make.centerY.equalTo(safeAreaLayoutGuide.snp.top)
                .offset(RoomScheduleLayout.navBarHeight / 2 + 2)
            make.size.equalTo(RoomScheduleLayout.backButtonSize)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
        }
        
        scrollView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(backButtonContainerView.snp.bottom).offset(RoomScheduleLayout.topSpacingAfterNav)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
        
        cardsStackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.right.equalToSuperview().inset(RoomScheduleLayout.horizontalPadding)
        }
        
        scheduleButton.snp.makeConstraints { make in
            make.top.equalTo(cardsStackView.snp.bottom).offset(24)
            make.left.right.equalToSuperview().inset(RoomScheduleLayout.buttonHorizontalInset)
            make.height.equalTo(RoomScheduleLayout.buttonHeight)
            make.bottom.equalToSuperview().offset(-24)
        }
    }
    
    public func setupStyles() {
        backgroundColor = RoomColors.g8
        backButtonContainerView.backgroundColor = .white
    }
    
    public func setupBindings() {
        backButton.isUserInteractionEnabled = true
        backButton.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleBackButtonTapped))
        )
        scheduleButton.addTarget(self,
                                 action: #selector(handleScheduleButtonTapped),
                                 for: .touchUpInside)
    }
    
    // MARK: - Store subscriptions
    
    private func subscribeLoginStore() {
        LoginStore.shared.state.subscribe(StatePublisherSelector(keyPath: \LoginState.loginUserInfo))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if case .edit = self.mode { return }
                if !self.hasUserEditedRoomName {
                    self.scheduleOptions.roomName = self.defaultRoomName()
                    self.refreshCurrentItemValues()
                }
            }
            .store(in: &cancellableSet)
    }
    
    // MARK: - Menu items (Model)
    
    private func menuItems() -> [RoomScheduleMenuItem] {
        var items: [RoomScheduleMenuItem] = []
        
        items.append(makeRoomNameItem())
        items.append(makeStartTimeItem())
        items.append(makeDurationItem())
        items.append(makeTimeZoneItem())
        items.append(makeParticipantsItem())
        
        if case .create = mode {
            items.append(makeEncryptionItem())
            if isEncryptionEnabled {
                items.append(makePasswordItem())
            }
        }
        
        if case .create = mode {
            items.append(makeMuteAllItem())
            items.append(makeDisableVideoItem())
        }
        
        return items
    }
    
    // MARK: - Rendering
    
    private func renderMenuItems() {
        currentItems = menuItems()
        var itemsByCard: [RoomScheduleCardID: [RoomScheduleMenuItem]] = [:]
        for item in currentItems {
            itemsByCard[item.card, default: []].append(item)
        }
        
        valueViewByID.removeAll()
        rowByID.removeAll()
        idByTextField.removeAll()
        
        for (card, container) in cardContainers {
            for view in container.arrangedSubviews {
                container.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            
            let items = itemsByCard[card] ?? []
            for item in items {
                let row = makeRow(for: item)
                container.addArrangedSubview(row)
                rowByID[item.id] = row
            }
            
            container.isHidden = items.isEmpty
        }
    }
    
    private func refreshCurrentItemValues() {
        let newItems = menuItems()
        if newItems.map({ $0.id }) != currentItems.map({ $0.id }) {
            renderMenuItems()
            return
        }
        currentItems = newItems
        for item in currentItems {
            apply(item: item)
        }
    }
    
    private func apply(item: RoomScheduleMenuItem) {
        guard let view = valueViewByID[item.id] else { return }
        switch item.kind {
        case .accessory:
            if let participantsView = view as? RoomScheduleParticipantsValueView {
                participantsView.update(avatarURLs: selectedAttendees.map { $0.avatarURL },
                                        countText: item.value,
                                        placeholder: item.valuePlaceholder)
                return
            }
            if let label = view as? UILabel {
                if let value = item.value, !value.isEmpty {
                    label.text = value
                } else {
                    label.text = item.valuePlaceholder ?? ""
                }
            }
        case .editableText:
            if let field = view as? UITextField {
                if !field.isFirstResponder {
                    field.text = item.value
                }
            }
        case .switchToggle:
            if let toggle = view as? UISwitch, toggle.isOn != item.isOn {
                toggle.setOn(item.isOn, animated: true)
            }
        }
    }
    
    // MARK: - Row construction

    private func makeRow(for item: RoomScheduleMenuItem) -> UIStackView {
        let titleLabel = makeLabel(item.title)
        switch item.kind {
        case .accessory(let chevron):
            if item.id == .participants {
                let valueView = makeParticipantsValueView()
                valueView.update(avatarURLs: selectedAttendees.map { $0.avatarURL },
                                 countText: item.value,
                                 placeholder: item.valuePlaceholder)
                valueViewByID[item.id] = valueView
                let row = makeAccessoryRow(titleLabel, valueView, chevron: chevron)
                attachTapGesture(to: row, id: item.id)
                return row
            }
            let valueLabel = makeValueLabel()
            if let value = item.value, !value.isEmpty {
                valueLabel.text = value
            } else {
                valueLabel.text = item.valuePlaceholder ?? ""
            }
            valueViewByID[item.id] = valueLabel
            let row = makeAccessoryRow(titleLabel, valueLabel, chevron: chevron)
            attachTapGesture(to: row, id: item.id)
            return row
            
        case .editableText(let placeholder, let keyboardType):
            let field = makeValueField(placeholder: placeholder)
            field.text = item.value
            field.keyboardType = keyboardType
            idByTextField[ObjectIdentifier(field)] = item.id
            valueViewByID[item.id] = field
            let row = makeAccessoryRow(titleLabel, field, chevron: .none)
            attachTapGesture(to: row, id: item.id)
            return row
            
        case .switchToggle:
            let toggle = makeSwitch()
            toggle.isOn = item.isOn
            toggle.addAction(for: .valueChanged) { [weak self] in
                guard let self = self else { return }
                let latest = self.item(for: item.id) ?? item
                latest.switchAction?(toggle.isOn)
            }
            valueViewByID[item.id] = toggle
            return makeSwitchRow(item.title, toggle)
        }
    }
    
    private func attachTapGesture(to row: UIStackView, id: RoomScheduleMenuID) {
        let gesture = RoomScheduleTapGesture(target: self, action: #selector(handleRowTapped(_:)))
        gesture.menuID = id
        row.addGestureRecognizer(gesture)
    }
    
    @objc private func handleRowTapped(_ gesture: RoomScheduleTapGesture) {
        guard let id = gesture.menuID, let item = item(for: id) else { return }
        switch item.kind {
        case .editableText:
            if let override = item.tapAction {
                override()
            } else if let field = valueViewByID[id] as? UITextField {
                field.becomeFirstResponder()
            }
        case .accessory:
            item.tapAction?()
        case .switchToggle:
            break
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleBackButtonTapped() {
        routerContext?.pop(animated: true)
    }
    
    @objc private func handleScheduleButtonTapped() {
        guard !isScheduling else { return }
        syncScheduleEndTime()
        scheduleOptions.scheduleAttendees = selectedAttendees.map { $0.userID }
        
        switch mode {
        case .create:
            performScheduleRoom()
        case .edit(let roomID):
            performUpdateRoom(roomID: roomID)
        }
    }
    
    private func performScheduleRoom() {
        if scheduleOptions.scheduleStartTime < Date.secondsSince1970(from: Date()) {
            showAtomicToast(text: .startTimeEarlierThanCurrent, style: .info, position: .center)
            return
        }
        let roomID = Self.generateRoomID(numberOfDigits: 6)
        
        isScheduling = true
        RoomStore.shared.scheduleRoom(roomID: roomID, options: scheduleOptions) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isScheduling = false
                switch result {
                case .success:
                    let info = self.makeScheduledRoomInfo(roomID: roomID)
                    self.onScheduled?(info)
                    self.routerContext?.pop(animated: true)
                case .failure(let error):
                    self.showFailureAlert(message: error.message, fallback: .scheduleRoomFailed)
                }
            }
        }
    }
    
    private func performUpdateRoom(roomID: String) {
        var flag: ScheduleRoomOptions.ModifyFlag = []
        if let original = originalRoomInfo {
            if scheduleOptions.roomName != original.roomName {
                flag.insert(.roomName)
            }
            if scheduleOptions.scheduleStartTime != original.scheduledStartTime {
                flag.insert(.scheduleStartTime)
            }
            if scheduleOptions.scheduleEndTime != original.scheduledEndTime {
                flag.insert(.scheduleEndTime)
            }
        } else {
            flag = [.roomName, .scheduleStartTime, .scheduleEndTime]
        }
        
        let originalIDs = Set(originalRoomInfo?.scheduleAttendees.map { $0.userID } ?? [])
        let newIDs = Set(selectedAttendees.map { $0.userID })
        let addedIDs = Array(newIDs.subtracting(originalIDs))
        let removedIDs = Array(originalIDs.subtracting(newIDs))
        
        var actions: [UpdateAction] = []
        if !flag.isEmpty {
            actions.append(.updateRoom(flag: flag))
        }
        if !addedIDs.isEmpty {
            actions.append(.addAttendees(addedIDs))
        }
        if !removedIDs.isEmpty {
            actions.append(.removeAttendees(removedIDs))
        }
        
        guard !actions.isEmpty else {
            routerContext?.pop(animated: true)
            return
        }
        
        isScheduling = true
        runUpdateActions(actions, roomID: roomID, at: 0)
    }
    
    private func runUpdateActions(_ actions: [UpdateAction], roomID: String, at index: Int) {
        guard index < actions.count else {
            isScheduling = false
            onUpdated?()
            if let window = self.window {
                window.showAtomicToast(text: .roomModifySuccess,
                                       style: .success,
                                       position: .center)
            }
            routerContext?.pop(animated: true)
            return
        }
        let completion: (Result<Void, ErrorInfo>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.runUpdateActions(actions, roomID: roomID, at: index + 1)
                case .failure(let error):
                    self.isScheduling = false
                    self.showAtomicToast(
                        text: InternalError(code: error.code, message: error.message).localizedMessage,
                        style: .error,
                        position: .center
                    )
                }
            }
        }
        switch actions[index] {
        case .updateRoom(let flag):
            RoomStore.shared.updateScheduledRoom(roomID: roomID,
                                                 options: scheduleOptions,
                                                 modifyFlag: flag,
                                                 completion: completion)
        case .addAttendees(let userIDs):
            RoomStore.shared.addScheduledAttendees(roomID: roomID, userIDList: userIDs, completion: completion)
        case .removeAttendees(let userIDs):
            RoomStore.shared.removeScheduledAttendees(roomID: roomID, userIDList: userIDs, completion: completion)
        }
    }
    
    private func makeScheduledRoomInfo(roomID: String) -> RoomScheduleInfo {
        return RoomScheduleInfo(
            roomID: roomID,
            roomName: scheduleOptions.roomName,
            roomType: roomType,
            scheduledStartTime: scheduleOptions.scheduleStartTime,
            scheduledEndTime: scheduleOptions.scheduleEndTime,
            password: scheduleOptions.password.isEmpty ? nil : scheduleOptions.password
        )
    }
    
    private static func generateRoomID(numberOfDigits: Int) -> String {
        let digits = max(1, min(numberOfDigits, 9))
        let minNumber = Int(pow(10.0, Double(digits - 1)))
        let maxNumber = Int(pow(10.0, Double(digits))) - 1
        let randomNumber = arc4random_uniform(UInt32(maxNumber - minNumber)) + UInt32(minNumber)
        return String(randomNumber)
    }
    
    private func showFailureAlert(message: String?, fallback: String) {
        let alert = UIAlertController(title: nil,
                                      message: message?.isEmpty == false ? message : fallback,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: .ok, style: .default))
        routerContext?.present(alert, animated: true, completion: nil)
    }
    
    @objc func handleKeyboardDoneTapped() {
        endEditing(true)
    }
    
    // MARK: - Keyboard avoidance
    
    private func registerKeyboardNotifications() {
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(handleKeyboardWillChangeFrame(_:)),
                           name: UIResponder.keyboardWillChangeFrameNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleKeyboardWillHide(_:)),
                           name: UIResponder.keyboardWillHideNotification,
                           object: nil)
    }
    
    @objc private func handleKeyboardWillChangeFrame(_ note: Notification) {
        guard let info = note.userInfo,
              let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        let converted = self.convert(endFrame, from: nil)
        let overlap = max(0, self.bounds.maxY - converted.minY)
        let curveRaw = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? UIView.AnimationCurve.easeInOut.rawValue
        let options = UIView.AnimationOptions(rawValue: UInt(curveRaw) << 16)
        
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.scrollView.contentInset.bottom = overlap
            if #available(iOS 11.1, *) {
                self.scrollView.verticalScrollIndicatorInsets.bottom = overlap
            } else {
                self.scrollView.scrollIndicatorInsets.bottom = overlap
            }
        }, completion: { _ in
            self.scrollActiveFieldToVisible()
        })
    }
    
    @objc private func handleKeyboardWillHide(_ note: Notification) {
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = 0
            if #available(iOS 11.1, *) {
                self.scrollView.verticalScrollIndicatorInsets.bottom = 0
            } else {
                self.scrollView.scrollIndicatorInsets.bottom = 0
            }
        }
    }
    
    private func scrollActiveFieldToVisible() {
        for (_, view) in valueViewByID {
            if let field = view as? UITextField, field.isFirstResponder {
                let target = field.convert(field.bounds, to: scrollView)
                scrollView.scrollRectToVisible(target.insetBy(dx: 0, dy: -20), animated: true)
                return
            }
        }
    }
    
    // MARK: - Lookup helpers
    
    fileprivate func item(for id: RoomScheduleMenuID) -> RoomScheduleMenuItem? {
        return currentItems.first(where: { $0.id == id })
    }
}

// MARK: - UITextFieldDelegate
extension RoomScheduleView: UITextFieldDelegate {
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        guard let id = idByTextField[ObjectIdentifier(textField)],
              let item = item(for: id) else {
            return
        }
        item.commitTextAction?(textField.text ?? "")
    }
    
    public func textField(_ textField: UITextField,
                          shouldChangeCharactersIn range: NSRange,
                          replacementString string: String) -> Bool {
        guard let id = idByTextField[ObjectIdentifier(textField)],
              let item = item(for: id) else {
            return true
        }
        let current = textField.text ?? ""
        return item.shouldAcceptTextChange?(current, range, string) ?? true
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - Item builders
private extension RoomScheduleView {
    
    func makeRoomNameItem() -> RoomScheduleMenuItem {
        return RoomScheduleMenuItem(
            id: .roomName,
            card: .info,
            title: .roomName,
            kind: .editableText(placeholder: .inputRoomName, keyboardType: .default),
            value: scheduleOptions.roomName,
            tapAction: nil,
            commitTextAction: { [weak self] text in
                self?.handleRoomNameCommitted(text)
            },
            shouldAcceptTextChange: { [weak self] current, range, replacement in
                if let ns = current as NSString? {
                    self?.scheduleOptions.roomName = ns.replacingCharacters(in: range, with: replacement)
                }
                return true
            }
        )
    }
    
    func makeStartTimeItem() -> RoomScheduleMenuItem {
        return RoomScheduleMenuItem(
            id: .startTime,
            card: .info,
            title: .startTime,
            kind: .accessory(chevron: .down),
            value: formattedStartTime(),
            tapAction: { [weak self] in self?.handleStartTimeTapped() }
        )
    }
    
    func makeDurationItem() -> RoomScheduleMenuItem {
        let display = String.roomDurationDisplayString(hours: durationMinutes / 60,
                                                       minutes: durationMinutes % 60)
        return RoomScheduleMenuItem(
            id: .duration,
            card: .info,
            title: .duration,
            kind: .accessory(chevron: .down),
            value: display,
            tapAction: { [weak self] in self?.handleDurationTapped() }
        )
    }
    
    func makeTimeZoneItem() -> RoomScheduleMenuItem {
        return RoomScheduleMenuItem(
            id: .timeZone,
            card: .info,
            title: .timeZone,
            kind: .accessory(chevron: .down),
            value: RoomTimeZoneSelectViewController.displayString(for: timeZone),
            valuePlaceholder: .timeZoneDefault,
            tapAction: { [weak self] in self?.handleTimeZoneTapped() }
        )
    }
    
    func makeParticipantsItem() -> RoomScheduleMenuItem {
        let count = selectedAttendees.count
        let value: String? = count > 0
            ? "roomkit_format_add_attendee".localizedReplace("\(count)")
            : nil
        return RoomScheduleMenuItem(
            id: .participants,
            card: .info,
            title: .participants,
            kind: .accessory(chevron: .right),
            value: value,
            valuePlaceholder: .addAction,
            tapAction: { [weak self] in self?.handleParticipantsTapped() }
        )
    }
    
    func makeEncryptionItem() -> RoomScheduleMenuItem {
        return RoomScheduleMenuItem(
            id: .encryption,
            card: .security,
            title: .roomEncryption,
            kind: .switchToggle,
            isOn: isEncryptionEnabled,
            switchAction: { [weak self] isOn in
                self?.handleEncryptionSwitchChanged(isOn: isOn)
            }
        )
    }
    
    func makePasswordItem() -> RoomScheduleMenuItem {
        let passwordLength = RoomScheduleLayout.passwordDigits
        return RoomScheduleMenuItem(
            id: .password,
            card: .security,
            title: .roomPassword,
            kind: .editableText(placeholder: .inputPassword, keyboardType: .numberPad),
            value: scheduleOptions.password,
            tapAction: nil,
            commitTextAction: { [weak self] text in
                self?.scheduleOptions.password = text
            },
            shouldAcceptTextChange: { current, range, replacement in
                if replacement.isEmpty { return true }
                guard replacement.allSatisfy({ $0.isNumber }) else { return false }
                let newLength = current.count - range.length + replacement.count
                return newLength <= passwordLength
            }
        )
    }
    
    func makeMuteAllItem() -> RoomScheduleMenuItem {
        return RoomScheduleMenuItem(
            id: .muteAll,
            card: .control,
            title: .muteAll,
            kind: .switchToggle,
            isOn: scheduleOptions.isAllMicrophoneDisabled,
            switchAction: { [weak self] isOn in
                self?.scheduleOptions.isAllMicrophoneDisabled = isOn
            }
        )
    }
    
    func makeDisableVideoItem() -> RoomScheduleMenuItem {
        return RoomScheduleMenuItem(
            id: .disableVideo,
            card: .control,
            title: .disableAllVideo,
            kind: .switchToggle,
            isOn: scheduleOptions.isAllCameraDisabled,
            switchAction: { [weak self] isOn in
                self?.scheduleOptions.isAllCameraDisabled = isOn
            }
        )
    }
}

// MARK: - Business logic handlers
private extension RoomScheduleView {
    
    func handleRoomNameCommitted(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            scheduleOptions.roomName = defaultRoomName()
        } else {
            scheduleOptions.roomName = trimmed
        }
        refreshCurrentItemValues()
    }
    
    func handleStartTimeTapped() {
        let panel = RoomDateTimePickerPanel(initialDate: currentStartDate(),
                                            timeZone: timeZone)
        panel.onConfirm = { [weak self] picked in
            guard let self = self else { return }
            self.scheduleOptions.scheduleStartTime = Date.secondsSince1970(from: picked)
            self.syncScheduleEndTime()
            self.refreshCurrentItemValues()
        }
        panel.show(in: self, animated: true)
    }
    
    func handleDurationTapped() {
        let panel = RoomDurationPickerPanel(initialMinutes: durationMinutes)
        panel.onConfirm = { [weak self] totalMinutes in
            guard let self = self else { return }
            self.durationMinutes = totalMinutes
            self.refreshCurrentItemValues()
        }
        panel.show(in: self, animated: true)
    }
    
    func handleTimeZoneTapped() {
        let selector = RoomTimeZoneSelectViewController(selectedTimeZoneIdentifier: timeZone.identifier)
        selector.onSelected = { [weak self] _, tz in
            guard let self = self else { return }
            self.timeZone = tz
            self.refreshCurrentItemValues()
        }
        routerContext?.push(selector, animated: true)
    }
    
    func handleParticipantsTapped() {
        let picker = RoomSelectAttendeesViewController(
            initialSelectedUserIDs: selectedAttendees.map { $0.userID }
        )
        picker.onConfirm = { [weak self] picked in
            guard let self = self else { return }
            self.selectedAttendees = picked
            self.refreshCurrentItemValues()
        }
        routerContext?.push(picker, animated: true)
    }
    
    func handleEncryptionSwitchChanged(isOn: Bool) {
        if isOn {
            if scheduleOptions.password.isEmpty {
                scheduleOptions.password = String.randomNumericPassword(length: RoomScheduleLayout.passwordDigits)
            }
        } else {
            scheduleOptions.password = ""
        }
        renderMenuItems()
    }
    
    func formattedStartTime() -> String {
        let date = currentStartDate()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let datePart = "\(comps.year ?? 0)\("roomkit_year_text".localized)"
            + "\(String(format: "%02d", comps.month ?? 0))\("roomkit_month_text".localized)"
            + "\(String(format: "%02d", comps.day ?? 0))\("roomkit_day_text".localized)"
        let timePart = String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
        return "\(datePart.trimmingCharacters(in: .whitespaces)) \(timePart)"
    }
    
    func currentStartDate() -> Date {
        return Date.date(fromSeconds: scheduleOptions.scheduleStartTime)
    }
    
    func syncScheduleEndTime() {
        scheduleOptions.scheduleEndTime = scheduleOptions.scheduleStartTime + durationMinutes * 60
    }
    
    var isEncryptionEnabled: Bool {
        return !scheduleOptions.password.isEmpty
    }
    
    func currentLoginNickname() -> String {
        guard let user = LoginStore.shared.state.value.loginUserInfo else {
            return ""
        }
        return user.nickname ?? user.userID
    }
    
    func defaultRoomName() -> String {
        let nickname = currentLoginNickname()
        return "roomkit_temporary_room_name".localizedReplace(nickname)
    }
    
    var hasUserEditedRoomName: Bool {
        return scheduleOptions.roomName != defaultRoomName()
    }
}

// MARK: - Tap gesture that carries a menu id

private final class RoomScheduleTapGesture: UITapGestureRecognizer {
    var menuID: RoomScheduleMenuID?
}

// MARK: - UIControl closure adapter

private extension UIControl {
    func addAction(for event: UIControl.Event, _ closure: @escaping () -> Void) {
        let trampoline = ControlActionTrampoline(closure: closure)
        addTarget(trampoline, action: #selector(ControlActionTrampoline.invoke), for: event)
        objc_setAssociatedObject(self,
                                 ObjectIdentifier(trampoline).debugDescription,
                                 trampoline,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private final class ControlActionTrampoline: NSObject {
    private let closure: () -> Void
    init(closure: @escaping () -> Void) { self.closure = closure }
    @objc func invoke() { closure() }
}

// MARK: - Localized strings (view-only)
private extension String {
    static let scheduleRoom = "roomkit_schedule_room".localized
    static let roomName = "roomkit_room_name".localized
    static let startTime = "roomkit_scheduled_start_time".localized
    static let duration = "roomkit_scheduled_duration".localized
    static let timeZone = "roomkit_scheduled_time_zone".localized
    static let participants = "roomkit_scheduled_attendees".localized
    static let addAction = "roomkit_add_member".localized
    static let roomEncryption = "roomkit_scheduled_room_encrypt".localized
    static let roomPassword = "roomkit_scheduled_room_password".localized
    static let muteAll = "roomkit_mute_all_audio".localized
    static let disableAllVideo = "roomkit_disable_all_video".localized

    static let timeZoneDefault = "roomkit_scheduled_time_zone".localized

    static let inputRoomName = "roomkit_conference_name_hint".localized
    static let inputPassword = "roomkit_please_enter_six_digit_password".localized

    static let ok = "roomkit_ok".localized
    static let scheduleRoomFailed = "roomkit_scheduled_create_failed".localized
    static let updateRoomFailed = "roomkit_scheduled_modify_failed".localized
    static let editRoom = "roomkit_amend_scheduled_room".localized
    static let save = "roomkit_save_scheduled_room".localized
    static let startTimeEarlierThanCurrent = "roomkit_start_time_earlier_than_current_time".localized
    static let roomModifySuccess = "roomkit_scheduled_room_modify_success".localized
}

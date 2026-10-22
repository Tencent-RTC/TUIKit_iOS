import UIKit
import SnapKit
import Combine
import AtomicXCore

final class RoomParticipantListView: UIView {

    private weak var popup: RoomPopup?
    private var cancellableSet = Set<AnyCancellable>()

    var onDismiss: (() -> Void)?

    func show(in host: UIView) {
        let popup = RoomPopup()
        popup.contentView.addSubview(self)
        let screenHeight = host.window?.bounds.height ?? UIScreen.main.bounds.height
        snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalTo(screenHeight * 0.84)
        }
        popup.onDismiss = { [weak self] _ in self?.onDismiss?() }
        self.popup = popup
        popup.show(in: host)
    }

    private let titleText = UILabel()
    private let searchInput = UITextField()
    private let searchEmptyView = UIView()
    private let searchEmptyImageView = UIImageView()
    private let searchEmptyTitleLabel = UILabel()
    private let searchEmptyDescLabel = UILabel()
    private let searchEmptyClearButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let footer = UIStackView()
    private let muteButton = UIButton(type: .custom)
    private let cameraButton = UIButton(type: .custom)
    private let moreButton = UIButton(type: .custom)

    private var roomID: String
    private var participants: [RoomParticipant] = []
    private var keyword: String = ""
    private var joinedCollapsed = false
    private var screenSharerID: String?

    private enum Row {
        case section(title: String, count: Int)
        case participant(RoomParticipant, isSelf: Bool)
    }
    private var rows: [Row] = []

    init(roomID: String) {
        self.roomID = roomID
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    private func setupViews() {
        addSubview(titleText)
        addSubview(searchInput)
        addSubview(tableView)
        addSubview(searchEmptyView)
        addSubview(footer)
        footer.addArrangedSubview(muteButton)
        footer.addArrangedSubview(cameraButton)
        footer.addArrangedSubview(moreButton)
    }

    private func setupConstraints() {
        titleText.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.top.equalToSuperview().offset(4)
            $0.trailing.equalToSuperview().offset(-16)
        }
        searchInput.snp.makeConstraints {
            $0.top.equalTo(titleText.snp.bottom).offset(12)
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.height.equalTo(32)
        }
        tableView.snp.makeConstraints {
            $0.top.equalTo(searchInput.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(footer.snp.top).offset(-10)
        }
        searchEmptyView.snp.makeConstraints {
            $0.top.equalTo(searchInput.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(footer.snp.top).offset(-10)
        }
        footer.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.bottom.equalToSuperview().offset(-14)
            $0.height.equalTo(34)
        }
        [muteButton, cameraButton, moreButton].forEach {
            $0.snp.makeConstraints { $0.height.equalToSuperview() }
        }
    }

    private func makeKeyboardToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(endSearching)),
        ]
        return toolbar
    }

    @objc private func endSearching() {
        searchInput.resignFirstResponder()
    }

    private func setupStyles() {
        backgroundColor = UIColor.roomKitBgSurface
        titleText.font = .systemFont(ofSize: 15, weight: .bold)
        titleText.textColor = UIColor.roomKitFgPrimary
        titleText.text = .participantsPanel

        searchInput.font = .systemFont(ofSize: 11)
        searchInput.textColor = UIColor.roomKitFgPrimary
        searchInput.attributedPlaceholder = NSAttributedString(
            string: .participantsSearchPlaceholder,
            attributes: [.foregroundColor: UIColor.roomKitFgTertiary]
        )
        searchInput.backgroundColor = UIColor.roomKitBgCanvas
        searchInput.layer.cornerRadius = 8
        searchInput.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 34, height: 32))
        searchInput.leftViewMode = .always
        let searchIcon = UIImageView(image: RoomKitResources.image(named: "roomkit_icon_search_tertiary"))
        searchIcon.contentMode = .scaleAspectFit
        searchIcon.frame = CGRect(x: 10, y: 9, width: 14, height: 14)
        searchInput.leftView?.addSubview(searchIcon)
        searchInput.clearButtonMode = .never
        searchInput.inputAccessoryView = makeKeyboardToolbar()

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        tableView.dataSource = self

        searchEmptyView.isHidden = true
        searchEmptyImageView.image = RoomKitResources.image(named: "roomkit_ill_participant_search_empty")
        searchEmptyImageView.contentMode = .scaleAspectFit
        searchEmptyTitleLabel.text = .participantsSearchEmpty
        searchEmptyTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        searchEmptyTitleLabel.textColor = UIColor.roomKitFgPrimary
        searchEmptyTitleLabel.textAlignment = .center
        searchEmptyDescLabel.font = .systemFont(ofSize: 11)
        searchEmptyDescLabel.textColor = UIColor.roomKitFgTertiary
        searchEmptyDescLabel.textAlignment = .center
        searchEmptyDescLabel.numberOfLines = 0
        searchEmptyClearButton.setTitle(.participantsClearSearch, for: .normal)
        searchEmptyClearButton.setTitleColor(UIColor.roomKitFgPrimary, for: .normal)
        searchEmptyClearButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        searchEmptyClearButton.backgroundColor = UIColor.white
        searchEmptyClearButton.layer.cornerRadius = 15
        searchEmptyClearButton.layer.borderWidth = 1
        searchEmptyClearButton.layer.borderColor = UIColor.roomKitBorder.cgColor
        searchEmptyClearButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        searchEmptyClearButton.snp.makeConstraints { $0.height.equalTo(30) }

        let emptyStack = UIStackView(arrangedSubviews: [
            searchEmptyImageView, searchEmptyTitleLabel, searchEmptyDescLabel, searchEmptyClearButton,
        ])
        emptyStack.axis = .vertical
        emptyStack.alignment = .center
        emptyStack.spacing = 4
        emptyStack.setCustomSpacing(16, after: searchEmptyDescLabel)
        searchEmptyView.addSubview(emptyStack)
        emptyStack.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview().offset(20)
            $0.trailing.lessThanOrEqualToSuperview().offset(-20)
            $0.centerX.equalToSuperview()
        }
        tableView.delegate = self
        tableView.register(
            RoomParticipantSectionCell.self,
            forCellReuseIdentifier: RoomParticipantSectionCell.reuseIdentifier
        )
        tableView.register(
            RoomParticipantItemCell.self,
            forCellReuseIdentifier: RoomParticipantItemCell.reuseIdentifier
        )

        footer.spacing = 8
        footer.distribution = .fillEqually
        footer.isHidden = true
        [muteButton, cameraButton, moreButton].forEach { button in
            button.titleLabel?.font = .boldSystemFont(ofSize: 11)
            button.layer.cornerRadius = 17
            button.layer.borderWidth = 1
            applyFooterStyle(button, active: false)
        }
        moreButton.setTitle(.roomMore, for: .normal)
    }

    private func applyFooterStyle(_ button: UIButton, active: Bool) {
        if active {
            button.backgroundColor = UIColor.roomKitAccentSoft
            button.layer.borderColor = UIColor(argbHex: 0x470071E3).cgColor
            button.setTitleColor(UIColor.roomKitAccent, for: .normal)
        } else {
            button.backgroundColor = UIColor.roomKitBgSurface
            button.layer.borderColor = UIColor.roomKitBorder.cgColor
            button.setTitleColor(UIColor.roomKitFgPrimary, for: .normal)
        }
    }

    private func setupBindings() {
        searchInput.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        searchEmptyClearButton.addTarget(self, action: #selector(clearSearch), for: .touchUpInside)

        muteButton.addTarget(self, action: #selector(toggleAllMicrophones), for: .touchUpInside)
        cameraButton.addTarget(self, action: #selector(toggleAllCameras), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(showMoreSheet), for: .touchUpInside)

        let store = RoomParticipantStore.create(roomID: roomID)
        Publishers.CombineLatest3(
            store.state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.participantList)),
            RoomStore.shared.state.subscribe(StatePublisherSelector(keyPath: \RoomState.currentRoom)),
            store.state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.participantWithScreen))
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] participants, room, screenParticipant in
            guard let self, room?.roomID == self.roomID, let room else { return }
            self.screenSharerID = screenParticipant?.userID
            self.render(participants: participants, room: room)
        }
        .store(in: &cancellableSet)
    }


    private func render(participants: [RoomParticipant], room: RoomInfo) {
        self.participants = participants
        updateList()
        updateTitle(count: participants.count)
        updateFooter(room: room, participants: participants)
    }

    private func updateTitle(count: Int) {
        titleText.text = count == 0
            ? .participantsPanel
            : RoomKitResources.localizedFormat("roomkit.participants.panel_count", "\(count)")
    }

    private func updateList() {
        let filtered = keyword.isEmpty
            ? participants
            : participants.filter { $0.displayName.localizedCaseInsensitiveContains(keyword) }
        let showEmpty = filtered.isEmpty && !keyword.isEmpty
        searchEmptyView.isHidden = !showEmpty
        tableView.isHidden = showEmpty
        if showEmpty {
            let text = String(format: .participantsSearchEmptyDesc, keyword)
            let attributed = NSMutableAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.roomKitFgTertiary,
                ]
            )
            if let range = text.range(of: keyword) {
                attributed.addAttributes(
                    [
                        .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                        .foregroundColor: UIColor.roomKitFgPrimary,
                    ],
                    range: NSRange(range, in: text)
                )
            }
            searchEmptyDescLabel.attributedText = attributed
        }
        let localUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        var next: [Row] = [.section(title: .participantsJoined, count: filtered.count)]
        if !joinedCollapsed {
            filtered.forEach { next.append(.participant($0, isSelf: $0.userID == localUserID)) }
        }
        rows = next
        tableView.reloadData()
    }

    private func updateFooter(room: RoomInfo, participants: [RoomParticipant]) {
        let localUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let isPrivileged = participants.contains {
            $0.userID == localUserID && ($0.role == .owner || $0.role == .admin)
        }
        footer.isHidden = !isPrivileged
        muteButton.setTitle(room.isAllMicrophoneDisabled ? .participantsUnmuteAll : .participantsMuteAll, for: .normal)
        applyFooterStyle(muteButton, active: room.isAllMicrophoneDisabled)
        cameraButton.setTitle(room.isAllCameraDisabled ? .participantsCamOnAll : .participantsCamOffAll, for: .normal)
        applyFooterStyle(cameraButton, active: room.isAllCameraDisabled)
    }


    @objc private func searchTextChanged() {
        keyword = searchInput.text?.trimmingCharacters(in: .whitespaces) ?? ""
        updateList()
    }

    @objc private func clearSearch() {
        searchInput.text = ""
        searchTextChanged()
    }

    @objc private func toggleAllMicrophones() {
        toggleAllDevices(.microphone)
    }

    @objc private func toggleAllCameras() {
        toggleAllDevices(.camera)
    }

    private func toggleAllDevices(_ deviceType: DeviceType) {
        let room = RoomStore.shared.state.value.currentRoom
        guard room?.roomID == roomID, let room else { return }
        let disable: Bool
        let done: String
        if deviceType == .microphone {
            disable = !room.isAllMicrophoneDisabled
            done = disable ? .participantsMuteAllDone : .participantsUnmuteAllDone
        } else {
            disable = !room.isAllCameraDisabled
            done = disable ? .participantsCamOffAllDone : .participantsCamOnAllDone
        }
        RoomParticipantStore.create(roomID: roomID).disableAllDevices(
            device: deviceType,
            disable: disable
        ) { result in
            switch result {
            case .success: RoomToast.show(done)
            case .failure(let error): ErrorLocalized.showError(code: error.code, message: error.message)
            }
        }
    }

    @objc private func showMoreSheet() {
        let room = RoomStore.shared.state.value.currentRoom
        guard room?.roomID == roomID, let room else { return }
        let sheet = RoomParticipantMoreSheet(roomID: roomID)
        sheet.show(room: room, in: self)
    }

    private func showActionSheet(participant: RoomParticipant) {
        let sheet = RoomParticipantActionSheet(roomID: roomID)
        sheet.show(target: participant, in: self)
    }
}

// MARK: - UITableViewDataSource / UITableViewDelegate

extension RoomParticipantListView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if case .section = rows[indexPath.row] { return 28 }
        return 50
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case let .section(title, count):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: RoomParticipantSectionCell.reuseIdentifier,
                for: indexPath
            ) as! RoomParticipantSectionCell
            cell.bind(title: title, count: count, collapsed: joinedCollapsed)
            cell.onToggle = { [weak self] in
                guard let self else { return }
                joinedCollapsed.toggle()
                updateList()
            }
            return cell
        case let .participant(value, isSelf):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: RoomParticipantItemCell.reuseIdentifier,
                for: indexPath
            ) as! RoomParticipantItemCell
            cell.bind(participant: value, isSelf: isSelf, isSharing: value.userID == screenSharerID)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard case let .participant(value, _) = rows[indexPath.row] else { return }
        showActionSheet(participant: value)
    }
}

private extension String {
    static var roomMore: String { RoomKitResources.localizedString("roomkit.room.more") }
    static var participantsPanel: String { RoomKitResources.localizedString("roomkit.participants.panel") }
    static var participantsPanelCount: String { RoomKitResources.localizedString("roomkit.participants.panel_count") }
    static var participantsJoined: String { RoomKitResources.localizedString("roomkit.participants.joined") }
    static var participantsSearchEmpty: String { RoomKitResources.localizedString("roomkit.participants.search_empty") }
    static var participantsSearchEmptyDesc: String { RoomKitResources.localizedString("roomkit.participants.search_empty_desc") }
    static var participantsClearSearch: String { RoomKitResources.localizedString("roomkit.participants.clear_search") }
    static var participantsSearchPlaceholder: String { RoomKitResources.localizedString("roomkit.participants.search_placeholder") }
    static var participantsMuteAll: String { RoomKitResources.localizedString("roomkit.participants.mute_all") }
    static var participantsUnmuteAll: String { RoomKitResources.localizedString("roomkit.participants.unmute_all") }
    static var participantsMuteAllDone: String { RoomKitResources.localizedString("roomkit.participants.mute_all_done") }
    static var participantsUnmuteAllDone: String { RoomKitResources.localizedString("roomkit.participants.unmute_all_done") }
    static var participantsCamOffAll: String { RoomKitResources.localizedString("roomkit.participants.cam_off_all") }
    static var participantsCamOnAll: String { RoomKitResources.localizedString("roomkit.participants.cam_on_all") }
    static var participantsCamOffAllDone: String { RoomKitResources.localizedString("roomkit.participants.cam_off_all_done") }
    static var participantsCamOnAllDone: String { RoomKitResources.localizedString("roomkit.participants.cam_on_all_done") }
}

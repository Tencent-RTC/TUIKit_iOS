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
    private let emptyView = UIView()
    private let emptyImageView = UIImageView()
    private let emptyTitleLabel = UILabel()
    private let emptyDescLabel = UILabel()
    private let clearButton = UIButton(type: .system)
    private let joinedHeader = RoomParticipantSectionView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let footer = UIStackView()
    private let muteAllMicrophoneButton = UIButton(type: .custom)
    private let muteAllCameraButton = UIButton(type: .custom)
    private let moreButton = UIButton(type: .custom)

    private var roomID: String
    private var participants: [RoomParticipant] = []
    private var keyword: String = ""
    private var isCollapsed = false
    private var displayedParticipants: [RoomParticipant] = []

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
        addSubview(joinedHeader)
        addSubview(tableView)
        addSubview(emptyView)
        addSubview(footer)
        footer.addArrangedSubview(muteAllMicrophoneButton)
        footer.addArrangedSubview(muteAllCameraButton)
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
        joinedHeader.snp.makeConstraints {
            $0.top.equalTo(searchInput.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(28)
        }
        tableView.snp.makeConstraints {
            $0.top.equalTo(joinedHeader.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(footer.snp.top).offset(-10)
        }
        emptyView.snp.makeConstraints {
            $0.top.equalTo(searchInput.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(footer.snp.top).offset(-10)
        }
        footer.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.trailing.equalToSuperview().offset(-16)
            $0.bottom.equalToSuperview().offset(-10)
            $0.height.equalTo(34)
        }
        [muteAllMicrophoneButton, muteAllCameraButton, moreButton].forEach {
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
        tableView.rowHeight = 50
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 16, right: 0)
        tableView.dataSource = self

        emptyView.isHidden = true
        emptyImageView.image = RoomKitResources.image(named: "roomkit_ill_participant_search_empty")
        emptyImageView.contentMode = .scaleAspectFit
        emptyTitleLabel.text = .participantsSearchEmpty
        emptyTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        emptyTitleLabel.textColor = UIColor.roomKitFgPrimary
        emptyTitleLabel.textAlignment = .center
        emptyDescLabel.font = .systemFont(ofSize: 11)
        emptyDescLabel.textColor = UIColor.roomKitFgTertiary
        emptyDescLabel.textAlignment = .center
        emptyDescLabel.numberOfLines = 0
        clearButton.setTitle(.participantsClearSearch, for: .normal)
        clearButton.setTitleColor(UIColor.roomKitFgPrimary, for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .medium)
        clearButton.backgroundColor = UIColor.white
        clearButton.layer.cornerRadius = 15
        clearButton.layer.borderWidth = 1
        clearButton.layer.borderColor = UIColor.roomKitBorder.cgColor
        clearButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        clearButton.snp.makeConstraints { $0.height.equalTo(30) }

        let emptyStack = UIStackView(arrangedSubviews: [
            emptyImageView, emptyTitleLabel, emptyDescLabel, clearButton,
        ])
        emptyStack.axis = .vertical
        emptyStack.alignment = .center
        emptyStack.spacing = 4
        emptyStack.setCustomSpacing(16, after: emptyDescLabel)
        emptyView.addSubview(emptyStack)
        emptyStack.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.greaterThanOrEqualToSuperview().offset(20)
            $0.trailing.lessThanOrEqualToSuperview().offset(-20)
            $0.centerX.equalToSuperview()
        }
        tableView.delegate = self
        tableView.register(
            RoomParticipantListCell.self,
            forCellReuseIdentifier: RoomParticipantListCell.reuseIdentifier
        )

        joinedHeader.setTitle(.participantsJoined)
        joinedHeader.updateCollapsed(isCollapsed)

        footer.spacing = 8
        footer.distribution = .fillEqually
        footer.isHidden = true
        [muteAllMicrophoneButton, muteAllCameraButton, moreButton].forEach { button in
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
            button.layer.borderColor = UIColor.roomKitAccentBorder.cgColor
            button.setTitleColor(UIColor.roomKitAccent, for: .normal)
        } else {
            button.backgroundColor = UIColor.roomKitBgSurface
            button.layer.borderColor = UIColor.roomKitBorder.cgColor
            button.setTitleColor(UIColor.roomKitFgPrimary, for: .normal)
        }
    }

    private func setupBindings() {
        searchInput.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        clearButton.addTarget(self, action: #selector(clearSearch), for: .touchUpInside)

        muteAllMicrophoneButton.addTarget(self, action: #selector(toggleAllMicrophones), for: .touchUpInside)
        muteAllCameraButton.addTarget(self, action: #selector(toggleAllCameras), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(showMorePopup), for: .touchUpInside)
        joinedHeader.onTap = { [weak self] in
            guard let self else { return }
            isCollapsed.toggle()
            joinedHeader.updateCollapsed(isCollapsed)
            updateList()
        }

        let participantStore = RoomParticipantStore.create(roomID: roomID)
        participantStore.state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.participantList))
            .receive(on: RunLoop.main)
            .sink { [weak self] participants in
                guard let self else { return }
                self.participants = participants
                self.updateList()
            }
            .store(in: &cancellableSet)

        RoomStore.shared.state.subscribe(StatePublisherSelector(keyPath: \RoomState.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] room in
                guard let self, let room, room.roomID == self.roomID else { return }
                self.updateTitle(count: room.participantCount)
                self.joinedHeader.updateCount(room.participantCount)
                self.updateFooter(room: room)
            }
            .store(in: &cancellableSet)

        participantStore.state.subscribe(StatePublisherSelector(keyPath: \RoomParticipantState.localParticipant))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self,
                      let room = RoomStore.shared.state.value.currentRoom,
                      room.roomID == self.roomID else { return }
                self.updateFooter(room: room)
            }
            .store(in: &cancellableSet)

    }

    private func updateTitle(count: Int) {
        titleText.text = count == 0
            ? .participantsPanel
            : RoomKitResources.localizedFormat("roomkit.participants.panel_count", "\(count)")
    }

    private func updateList() {
        let filtered = filteredParticipants()
        updateSearchEmptyState(for: filtered)
        displayedParticipants = isCollapsed ? [] : filtered
        tableView.reloadData()
    }

    private func filteredParticipants() -> [RoomParticipant] {
        guard !keyword.isEmpty else { return participants }
        return participants.filter { $0.displayName.localizedCaseInsensitiveContains(keyword) }
    }

    private func updateSearchEmptyState(for filtered: [RoomParticipant]) {
        let showEmpty = filtered.isEmpty && !keyword.isEmpty
        emptyView.isHidden = !showEmpty
        joinedHeader.isHidden = showEmpty
        tableView.isHidden = showEmpty
        if showEmpty {
            updateSearchEmptyDescription()
        }
    }

    private func updateSearchEmptyDescription() {
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
        emptyDescLabel.attributedText = attributed
    }

    private func isSelf(_ participant: RoomParticipant) -> Bool {
        participant.userID == LoginStore.shared.state.value.loginUserInfo?.userID
    }

    private func canAction(on participant: RoomParticipant) -> Bool {
        if isSelf(participant) { return true }
        let localRole = RoomParticipantStore.create(roomID: roomID).state.value.localParticipant?.role
        return localRole?.canManage(participant.role) ?? false
    }

    private func updateFooter(room: RoomInfo) {
        let localRole = RoomParticipantStore.create(roomID: roomID).state.value.localParticipant?.role
        let isLocalOwnerOrAdmin = localRole == .owner || localRole == .admin
        footer.isHidden = !isLocalOwnerOrAdmin
        muteAllMicrophoneButton.setTitle(room.isAllMicrophoneDisabled ? .participantsUnmuteAll : .participantsMuteAll, for: .normal)
        applyFooterStyle(muteAllMicrophoneButton, active: room.isAllMicrophoneDisabled)
        muteAllCameraButton.setTitle(room.isAllCameraDisabled ? .participantsCamOnAll : .participantsCamOffAll, for: .normal)
        applyFooterStyle(muteAllCameraButton, active: room.isAllCameraDisabled)
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
        let room = RoomStore.shared.state.value.currentRoom
        guard room?.roomID == roomID, let room else { return }
        let disable = !room.isAllMicrophoneDisabled
        let done: String = disable ? .participantsMuteAllDone : .participantsUnmuteAllDone
        RoomParticipantStore.create(roomID: roomID).disableAllDevices(
            device: .microphone,
            disable: disable
        ) { result in
            switch result {
            case .success: RoomToast.show(done)
            case .failure(let error): ErrorLocalized.showError(code: error.code, message: error.message)
            }
        }
    }

    @objc private func toggleAllCameras() {
        let room = RoomStore.shared.state.value.currentRoom
        guard room?.roomID == roomID, let room else { return }
        let disable = !room.isAllCameraDisabled
        let done: String = disable ? .participantsCamOffAllDone : .participantsCamOnAllDone
        RoomParticipantStore.create(roomID: roomID).disableAllDevices(
            device: .camera,
            disable: disable
        ) { result in
            switch result {
            case .success: RoomToast.show(done)
            case .failure(let error): ErrorLocalized.showError(code: error.code, message: error.message)
            }
        }
    }

    @objc private func showMorePopup() {
        let room = RoomStore.shared.state.value.currentRoom
        guard room?.roomID == roomID, let room else { return }
        let popup = RoomParticipantMorePopup(roomID: roomID)
        popup.show(room: room, in: self)
    }

}

extension RoomParticipantListView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedParticipants.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let participant = displayedParticipants[indexPath.row]
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RoomParticipantListCell.reuseIdentifier,
            for: indexPath
        ) as! RoomParticipantListCell
        cell.selectionStyle = canAction(on: participant) ? .default : .none
        cell.bind(participant: participant)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let participant = displayedParticipants[indexPath.row]
        guard canAction(on: participant) else { return }
        let popup = RoomParticipantActionPopup(roomID: roomID)
        popup.show(target: participant, in: self)
    }
}

private extension String {
    static var roomMore: String { RoomKitResources.localizedString("roomkit.room.more") }
    static var participantsPanel: String { RoomKitResources.localizedString("roomkit.participants.panel") }
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

private final class RoomParticipantSectionView: UIView {

    var onTap: (() -> Void)?

    private let titleText = UILabel()
    private let countText = UILabel()
    private let chevron = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(titleText)
        addSubview(countText)
        addSubview(chevron)
    }

    private func setupConstraints() {
        chevron.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(24)
            $0.centerY.equalTo(titleText)
            $0.size.equalTo(12)
        }
        titleText.snp.makeConstraints {
            $0.leading.equalTo(chevron.snp.trailing).offset(6)
            $0.top.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-4)
        }
        countText.snp.makeConstraints {
            $0.leading.equalTo(titleText.snp.trailing).offset(6)
            $0.centerY.equalTo(titleText)
        }
    }

    private func setupStyles() {
        backgroundColor = .clear
        titleText.font = .boldSystemFont(ofSize: 11)
        titleText.textColor = UIColor.roomKitFgSecondary
        countText.font = .boldSystemFont(ofSize: 11)
        countText.textColor = UIColor.roomKitFgTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.image = RoomKitResources.image(named: "roomkit_icon_chevron_right_tertiary")
    }

    func setTitle(_ title: String) {
        titleText.text = title
    }

    func updateCollapsed(_ collapsed: Bool) {
        UIView.performWithoutAnimation {
            chevron.transform = collapsed ? .identity : CGAffineTransform(rotationAngle: .pi / 2)
        }
    }

    func updateCount(_ count: Int) {
        countText.text = "(\(count))"
        countText.isHidden = count == 0
    }

    @objc private func handleTap() {
        onTap?()
    }
}

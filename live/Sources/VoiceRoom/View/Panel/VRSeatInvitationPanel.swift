//
//  VRSeatInvitationPanel.swift
//  TUILiveKit
//
//  Created by adamsfliu on 2024/7/25.
//

import RTCCommon
import Combine
import TUICore
import AtomicXCore
import RTCRoomEngine
import AtomicXCore

class VRSeatInvitationPanel: RTCBaseView {
    private let liveID: String
    private let toastService: VRToastService
    private let routerManager: VRRouterManager
    private var cancellableSet: Set<AnyCancellable> = []
    private var audienceTupleList: [(audienceInfo: LiveUserInfo, isInvited: Bool)] = []
    private let seatIndex: Int
    
    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .g7
        label.font = UIFont.customFont(ofSize: 20)
        label.text = .inviteText
        return label
    }()
    
    private let subTitleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .g7
        label.font = UIFont.customFont(ofSize: 16, weight: .medium)
        label.text = .onlineAudienceText
        return label
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(VRInviteTakeSeatCell.self, forCellReuseIdentifier: VRInviteTakeSeatCell.identifier)
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)
        return tableView
    }()
    
    init(liveID: String, toastService: VRToastService, routerManager: VRRouterManager, seatIndex: Int) {
        self.liveID = liveID
        self.routerManager = routerManager
        self.toastService = toastService
        self.seatIndex = seatIndex
        super.init(frame: .zero)
        backgroundColor = .g2
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
    
    override func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(subTitleLabel)
        addSubview(tableView)
    }
    
    override func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20.scale375Height())
        }
        
        subTitleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24.scale375())
            make.height.equalTo(30.scale375Height())
            make.top.equalTo(titleLabel.snp.bottom)
            make.width.equalToSuperview()
        }
        
        tableView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(screenHeight * 2 / 3)
            make.top.equalTo(subTitleLabel.snp.bottom)
        }
    }
    
    override func bindInteraction() {
        tableView.delegate = self
        tableView.dataSource = self
        subscribeHostEventListener()
        subscribeUserListState()
        subscribeToastState()
    }
}

extension VRSeatInvitationPanel {
    private func subscribeUserListState() {
        let userListPublisher = audienceStore.state.subscribe(StatePublisherSelector(keyPath: \LiveAudienceState.audienceList))
        let seatListPublisher = seatStore.state.subscribe(StatePublisherSelector(keyPath: \LiveSeatState.seatList))
        let invitedUserIdsPublisher = coGuestStore.state.subscribe(StatePublisherSelector(keyPath: \CoGuestState.invitees))
        
        let combinedPublisher = Publishers.CombineLatest3(
            userListPublisher,
            seatListPublisher,
            invitedUserIdsPublisher
        )
        
        combinedPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] audienceList, seatList, invitedUsers in
                guard let self = self else { return }
                self.audienceTupleList = audienceList.filter { user in
                    !seatList.contains { $0.userInfo.userID == user.userID }
                }
                .map { audience in
                    (audience, self.coGuestStore.state.value.invitees.contains(where: {$0.userID == audience.userID}))
                }
                self.tableView.reloadData()
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeToastState() {
        toastService.subscribeToast({ [weak self] message in
            guard let self = self else { return }
            self.makeToast(message: message)
        })
    }
    
    private func subscribeHostEventListener() {
        coGuestStore.hostEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .onHostInvitationResponded(isAccept: let isAccept, guestUser: let guestUser):
                    if !isAccept {
                        toastService.showToast(String.localizedReplace(.requestRejectedText, replace: guestUser.userName.isEmpty ? guestUser.userID : guestUser.userName))
                    }
                case .onHostInvitationNoResponse(guestUser: _, reason: let reason):
                    if reason == .timeout {
                        toastService.showToast(.requestTimeoutText)
                    }
                default:
                    break
                }
            }
            .store(in: &cancellableSet)
    }
}

extension VRSeatInvitationPanel: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55.scale375Height()
    }
}

extension VRSeatInvitationPanel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return audienceTupleList.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VRInviteTakeSeatCell.identifier, for: indexPath)
        if let inviteTakeSeatCell = cell as? VRInviteTakeSeatCell {
            let audienceTuple = audienceTupleList[indexPath.row]
            inviteTakeSeatCell.updateUser(user: audienceTuple.audienceInfo)
            inviteTakeSeatCell.updateButtonView(isSelected: audienceTuple.isInvited)
            inviteTakeSeatCell.inviteEventClosure = { [weak self] user in
                guard let self = self, !self.coGuestStore.state.value.invitees.contains(where: { $0.userID == user.userID}) else { return }
                let seatAllTokenInConnect = seatStore.state.value.seatList.prefix(KSGConnectMaxSeatCount).allSatisfy({ $0.isLocked || $0.userInfo.userID != "" })

                if seatAllTokenInConnect && coHostStore.state.value.connected.count != 0 {
                    toastService.showToast(.seatAllTokenText)
                    return
                }
                self.coGuestStore.inviteToSeat(userID: user.userID, seatIndex: self.seatIndex, timeout: kSGDefaultTimeout, extraInfo: nil) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(()):
                        inviteTakeSeatCell.updateButtonView(isSelected: true)
                    case .failure(let error):
                        let err = InternalError(errorInfo: error)
                        toastService.showToast(err.localizedMessage)
                    }
                }
                
                if self.seatIndex != -1 {
                    self.routerManager.router(action: .routeTo(.anchor))
                }
            }
            inviteTakeSeatCell.cancelEventClosure = { [weak self] user in
                guard let self = self else { return }
                coGuestStore.cancelInvitation(inviteeID:  user.userID) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(()):
                        toastService.showToast(.inviteSeatCancelText)
                        inviteTakeSeatCell.updateButtonView(isSelected: false)
                    case .failure(let error):
                        let err = InternalError(errorInfo: error)
                        toastService.showToast(err.localizedMessage)
                    }
                }
            }
        }
        return cell
    }
}

extension VRSeatInvitationPanel {
    var coGuestStore: CoGuestStore {
        return CoGuestStore.create(liveID: liveID)
    }

    var coHostStore: CoHostStore {
        return CoHostStore.create(liveID: liveID)
    }

    var audienceStore: LiveAudienceStore {
        return LiveAudienceStore.create(liveID: liveID)
    }
    
    var seatStore: LiveSeatStore {
        return LiveSeatStore.create(liveID: liveID)
    }
    
}

fileprivate extension String {
    static let inviteText = internalLocalized("Invite")
    static let onlineAudienceText = internalLocalized("Online audience")
    static let inviteSeatCancelText = internalLocalized("Seat invitation has been canceled")
    static let seatAllTokenText = internalLocalized("The seats are all taken.")
    static let requestRejectedText = internalLocalized("xxx rejected")
    static let requestTimeoutText = internalLocalized("Invitation has timed out")
}

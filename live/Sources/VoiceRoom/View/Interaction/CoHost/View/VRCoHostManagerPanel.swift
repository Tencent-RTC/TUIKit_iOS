//
//  VRCoHostManagerPane.swift
//  TUILiveKit
//
//  Created by chensshi on 2025/9/17.
//

import Foundation
import RTCCommon
import Combine
import TUICore
import MJRefresh
import AtomicXCore
import RTCRoomEngine
import SnapKit

class VRCoHostManagerPanel: RTCBaseView {

    var onClickBack: (() -> ())?

    private var currentMode: DisplayMode = .coHost
    private enum DisplayMode {
        case coHost
        case battle
    }
    private let kCoHostTimeout = 10
    private var recommendedListCursor = ""
    private var recommendedList: [SeatUserInfo] = []
    private let toastService: VRToastService
    private let routerManager: VRRouterManager
    private var cancellableSet: Set<AnyCancellable> = []

    private lazy var buttonContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private lazy var coHostButton: UIButton = {
        let button = UIButton()
        button.setTitle(.startCoHostText, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.defaultTextColor, for: .normal)
        button.addTarget(self, action: #selector(switchToCoHost), for: .touchUpInside)
        return button
    }()

    private lazy var battleButton: UIButton = {
        let button = UIButton()
        button.setTitle(.requestBattleText, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.defaultTextColor, for: .normal)
        button.addTarget(self, action: #selector(switchToPK), for: .touchUpInside)
        return button
    }()

    private lazy var selectionIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = UIColor(hex: "#FFFFFF")
        label.font = UIFont(name: "PingFang SC", size: 16)
        label.text = .connectionTitleText
        return label
    }()

    private let disconnectButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = UIFont(name: "PingFang SC", size: 14)
        button.setTitleColor(.warningTextColor, for: .normal)
        button.setTitle(.disconnectText, for: .normal)
        button.setImage(internalImage("live_connection_disconnect"), for: .normal)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        button.backgroundColor = .clear
        button.contentHorizontalAlignment = .right
        button.isHidden = true
        return button
    }()

    private lazy var backButton: UIButton = {
        let view = UIButton(type: .system)
        view.setBackgroundImage(internalImage("live_back_icon"), for: .normal)
        view.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        return view
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(VRCoHostUserCell.self, forCellReuseIdentifier: VRCoHostUserCell.identifier)
        tableView.register(VRCoHostUserTableHeaderView.self, forHeaderFooterViewReuseIdentifier: VRCoHostUserTableHeaderView.identifier)
        return tableView
    }()

    private var tableHeightConstraint: Constraint?
    private let liveID: String

    private lazy var connectedView: VRCoHostCardConnectedView = {
        let view = VRCoHostCardConnectedView(liveID: liveID,toastService: toastService)
        view.isHidden = true
        return view
    }()

    init(liveID: String, toastService: VRToastService ,routerManager: VRRouterManager) {
        self.liveID = liveID
        self.toastService = toastService
        self.routerManager = routerManager
        super.init(frame: .zero)
        backgroundColor = .bgOperateColor
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        self.refreshRoomListData()
        self.switchToPK()
    }

    override func constructViewHierarchy() {
        addSubview(buttonContainer)
        buttonContainer.addSubview(coHostButton)
        buttonContainer.addSubview(battleButton)
        buttonContainer.addSubview(selectionIndicator)

        addSubview(disconnectButton)
        addSubview(tableView)
        addSubview(connectedView)
        addSubview(titleLabel)
    }

    override func activateConstraints() {
        buttonContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20.scale375())
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(27.scale375())
        }

        battleButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16.scale375())
            make.centerY.equalToSuperview()
        }

        coHostButton.snp.makeConstraints { make in
            make.leading.equalTo(battleButton.snp.trailing).offset(32.scale375())
            make.centerY.equalToSuperview()
        }

        selectionIndicator.snp.makeConstraints { make in
            make.bottom.equalToSuperview() 
            make.height.equalTo(1.scale375())
            make.width.equalTo(self.battleButton.snp.width)
            make.centerX.equalTo(coHostButton)
        }

        disconnectButton.snp.makeConstraints { make in
            make.trailing.equalTo(buttonContainer.snp.trailing).offset(-16.scale375())
            make.centerY.equalTo(buttonContainer)
            make.width.equalTo(88.scale375())
        }

        tableView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(buttonContainer.snp.bottom).offset(20.scale375())
            self.tableHeightConstraint = make.height.equalTo(575.scale375Height()).constraint
        }

        connectedView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(tableView)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(disconnectButton)
        }
    }

    override func bindInteraction() {
        tableView.delegate = self
        tableView.dataSource = self
        addRefreshDataEvent()
        subscribeConnectionState()
        subscribeToast()
        disconnectButton.addTarget(self, action: #selector(disconnect), for: .touchUpInside)
    }

    @objc private func backButtonClick(sender: UIButton) {
        onClickBack?()
    }

    @objc private func switchToCoHost() {
        currentMode = .coHost
        updateSelectionIndicator()
        battleButton.setTitleColor(.white.withAlphaComponent(0.3), for: .normal)
        coHostButton.setTitleColor(.defaultTextColor, for: .normal)
        tableView.reloadData()
    }

    @objc private func switchToPK() {
        currentMode = .battle
        updateSelectionIndicator()
        coHostButton.setTitleColor(.white.withAlphaComponent(0.3), for: .normal)
        battleButton.setTitleColor(.defaultTextColor, for: .normal)
        tableView.reloadData()
    }

    private func updateSelectionIndicator() {
        UIView.animate(withDuration: 0.2) { [weak self] in
            guard let self = self else {return }
            self.selectionIndicator.snp.remakeConstraints { make in
                make.bottom.equalToSuperview().offset(2.scale375())
                make.height.equalTo(1.scale375())
                make.width.equalTo(self.coHostButton.snp.width)
                make.centerX.equalTo(self.currentMode == .coHost ? self.coHostButton : self.battleButton)
            }
            self.layoutIfNeeded()
        }
    }

    private func showViewByState(isBattled: Bool, isConnected: Bool, connectedList: [SeatUserInfo]) {
        if isBattled && isConnected{
            tableView.isHidden = true
            connectedView.isHidden = false
            battleButton.isHidden = true
            coHostButton.isHidden = true
            selectionIndicator.isHidden = true
            titleLabel.isHidden = false
            titleLabel.text = .inBattleText
            disconnectButton.setTitle(.confirmEndBattleText, for: .normal)
            disconnectButton.removeTarget(self, action: #selector(disconnect), for: .touchUpInside)
            disconnectButton.addTarget(self, action: #selector(disconnectBattle), for: .touchUpInside)
            connectedView.render(connectedList: connectedList, isBattle: true)
            tableHeightConstraint?.update(offset: 140.scale375Height())
            connectedView.switchMode(isBattled: true)
        } else if isConnected {
            tableView.isHidden = isConnected
            connectedView.isHidden = !isConnected
            battleButton.isHidden = true
            coHostButton.isHidden = true
            selectionIndicator.isHidden = true
            titleLabel.isHidden = false
            titleLabel.text = .connectedTitleText
            disconnectButton.setTitle(.disconnectText, for: .normal)
            disconnectButton.removeTarget(self, action: #selector(disconnectBattle), for: .touchUpInside)
            disconnectButton.addTarget(self, action: #selector(disconnect), for: .touchUpInside)
            connectedView.render(connectedList: connectedList, isBattle: false)
            tableHeightConstraint?.update(offset: 180.scale375Height())
            connectedView.switchMode(isBattled: false)
        } else {
            tableView.isHidden = false
            connectedView.isHidden = true
            battleButton.isHidden = false
            coHostButton.isHidden = false
            selectionIndicator.isHidden = false
            titleLabel.isHidden = true
            tableHeightConstraint?.update(offset: 575.scale375Height())
        }
        layoutIfNeeded()
    }
}

extension VRCoHostManagerPanel {

    private func addRefreshDataEvent() {

        let header = MJRefreshNormalHeader(refreshingBlock: { [weak self] in
            guard let self = self else { return }
            refreshRoomListData()
            tableView.mj_header?.endRefreshing()
        })
        header.setTitle(.pullToRefreshText, for: .idle)
        header.setTitle(.releaseToRefreshText, for: .pulling)
        header.setTitle(.loadingText, for: .refreshing)
        header.lastUpdatedTimeLabel?.isHidden = true
        header.ignoredScrollViewContentInsetTop = tableView.contentInset.top
        tableView.mj_header = header

        let footer = MJRefreshAutoNormalFooter(refreshingBlock: { [weak self] in
            guard let self = self else { return }
            let cursor = recommendedListCursor
            if cursor != "" {
                // FIXME: 这里需不需要异步等待，后续验证
                fetchLiveList(cursor: cursor, count: 20)
                tableView.mj_footer?.endRefreshing()
            } else {
                tableView.mj_footer?.endRefreshingWithNoMoreData()
            }
        })
        footer.ignoredScrollViewContentInsetBottom = tableView.contentInset.bottom
        footer.setTitle(.loadingMoreText, for: .pulling)
        footer.setTitle("", for: .noMoreData)
        footer.setTitle(.loadingText, for: .refreshing)
        tableView.mj_footer = footer
    }

    private func refreshRoomListData() {
        fetchLiveList(cursor: recommendedListCursor, count: 20)
    }

    private func subscribeConnectionState() {
        let connectedListSelector = coHostStore.state.subscribe(StatePublisherSelector(keyPath: \CoHostState.connected))
        let inviteesSelector = StatePublisherSelector(keyPath: \CoHostState.invitees)
        let inviteesPublisher = coHostStore.state.subscribe(inviteesSelector)

        let battleStatePublisher = battleStore.state.subscribe(StatePublisherSelector(
            keyPath:\BattleState.battleUsers)
        )

        connectedListSelector
            .combineLatest(inviteesPublisher, battleStatePublisher)
            .receive(on: RunLoop.main)
            .sink { [weak self] connected,invitees,battleUsers in
                guard let self = self else { return }
                let selfLiveID = liveListStore.state.value.currentLive.liveID
                let cursor = recommendedListCursor
                if self.recommendedList.count > 0, cursor == "" {
                    tableView.mj_footer?.endRefreshingWithNoMoreData()
                } else {
                    tableView.mj_footer?.resetNoMoreData()
                }

                let isConnected = !connected.isEmpty
                let isBattled = battleUsers.count != 0
                showViewByState(isBattled: isBattled, isConnected: isConnected, connectedList: connected)

                disconnectButton.isHidden = connected.count <= 0
                tableView.reloadData()
            }
            .store(in: &cancellableSet)
    }

    private func subscribeToast() {
        toastService.subscribeToast { [weak self] message in
            guard let self = self else { return }
            if coHostState.connected.count == 0 {
                self.makeToast(message: message)
            }
        }
    }

    private func fetchLiveList(cursor: String, count: Int) {
        liveListStore.fetchLiveList(cursor: cursor,count: count,completion: { [weak self] result in
            guard let self = self else {return }
            switch result {
                case .success:
                    let responseCursor = liveListStore.state.value.liveListCursor
                    let liveList = liveListStore.state.value.liveList
                    
                    let connectedIds = Set(coHostStore.state.value.connected.map(\.liveID))
                    
                    let newRecommended = liveList
                        .filter { !$0.liveID.isEmpty}
                        .filter { !connectedIds.contains($0.liveID) }
                        .filter {
                            $0.liveID != self.liveListStore.state.value.currentLive.liveID
                        }
                        .map{
                            return SeatUserInfo(liveInfo: $0)
                        }
                    self.recommendedList = newRecommended
                    tableView.reloadData()
                case .failure(let error):
                    let err = InternalError(errorInfo: error)
                    toastService.showToast(err.localizedMessage)
                    break
            }
        })
    }

}

// MARK: - Action
extension VRCoHostManagerPanel {
    @objc
    private func disconnect() {
        let alertInfo = VRAlertInfo(description: .disconnectAlertText,
                                    imagePath: nil,
                                    cancelButtonInfo: (String.disconnectAlertCancelText, .defaultTextColor),
                                    defaultButtonInfo: (String.disconnectAlertDisconnectText, .warningTextColor)) { [weak self] alertPanel in
            guard let self = self else { return }
            routerManager.router(action: .dismiss(.alert))
            routerManager.router(action: .dismiss())
        } defaultClosure: { [weak self] alertPanel in
            guard let self = self else { return }
            coHostStore.exitHostConnection()
            routerManager.router(action: .dismiss())
        }
        let alertPanel = VRAlertPanel(alertInfo: alertInfo)
        routerManager.router(action: .present(.alert(info: alertInfo)))
    }

    @objc
    private func disconnectBattle() {
        let alertInfo = VRAlertInfo(description: .endBattleText,
                                    imagePath: nil,
                                    cancelButtonInfo: (String.disconnectAlertCancelText, .cancelTextColor),
                                    defaultButtonInfo: (String.confirmEndBattleText, .warningTextColor)) { [weak self] alertPanel in
            guard let self = self else { return }
            routerManager.router(action: .dismiss(.alert))
            routerManager.router(action: .dismiss())
        } defaultClosure: { [weak self] alertPanel in
            guard let self = self else { return }
            let battleID = battleStore.state.value.currentBattleInfo?.battleID ?? ""
            battleStore.exitBattle(battleID: battleID, completion: {_ in})
            routerManager.router(action: .dismiss())
        }
        let alertPanel = VRAlertPanel(alertInfo: alertInfo)
        routerManager.router(action: .present(.alert(info: alertInfo)))
    }

    private func handleConnectionError(_ error: ErrorInfo) {
        switch error.code {
            case TUIConnectionCode.roomNotExist.rawValue,
                TUIConnectionCode.connecting.rawValue,
                TUIConnectionCode.connectingOtherRoom.rawValue,
                TUIConnectionCode.full.rawValue,
                TUIConnectionCode.retry.rawValue:
                let error = InternalError(error: TUIConnectionCode(rawValue: error.code) ?? .unknown, message: error.message)
                toastService.showToast(error.localizedMessage)
            default:
                let error = InternalError(code: error.code, message: error.message)
                toastService.showToast(error.localizedMessage)
        }
    }
}

extension VRCoHostManagerPanel: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerId = VRCoHostUserTableHeaderView.identifier
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerId)
                as? VRCoHostUserTableHeaderView else {
            return nil
        }
        if section == 0 &&  coHostState.connected.count > 0 {
            headerView.titleLabel.text = .connectedTitleText + "(\(coHostState.connected.count))"
        } else {
            headerView.titleLabel.text = .recommendedTitleText
        }
        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30.scale375()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55.scale375Height()
    }
}

extension VRCoHostManagerPanel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recommendedList.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VRCoHostUserCell.identifier, for: indexPath)
        if let connectionUserCell = cell as? VRCoHostUserCell {
            let isEnable = !coHostStore.state.value.invitees.contains(where: { $0.liveID == recommendedList[indexPath.row].liveID})
            connectionUserCell.updateUser(recommendedList[indexPath.row],isBattle: currentMode == .battle, isEnable: isEnable)
            connectionUserCell.inviteEventClosure = { [weak self] user in
                guard let self = self else { return }
                if coHostState.invitees.contains(where: { $0.liveID == user.liveID }){
                    coHostStore.cancelHostConnection(toHostLiveID: user.liveID, completion: { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                            case .success():
                                break
                            case .failure(let error):
                                handleConnectionError(error)
                        }
                    })
                    return
                } else if coHostStore.state.value.invitees.count != 0 {
                    toastService.showToast(.inInviteText)
                    return
                }
                let extraInfo: String = currentMode == .coHost ? "" : "needRequestBattle"
                coHostStore
                    .requestHostConnection(
                        targetHost: user.liveID,
                        layoutTemplate: .hostStaticVoice6v6,
                        timeout: TimeInterval(kCoHostTimeout),
                        extraInfo: extraInfo ,
                        completion: { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                        case .success():
                            break
                        case .failure(let error):
                            handleConnectionError(error)
                    }
                })
            }
        }
        return cell
    }
}

extension VRCoHostManagerPanel {
    var liveListStore: LiveListStore {
        return LiveListStore.shared
    }

    var seatStore: LiveSeatStore {
        return LiveSeatStore.create(liveID: liveID)
    }

    var coHostStore: CoHostStore {
        return CoHostStore.create(liveID: liveID)
    }

    var coHostState: CoHostState {
        return coHostStore.state.value
    }

    var battleStore: BattleStore {
        return BattleStore.create(liveID: liveID)
    }
}

fileprivate extension SeatUserInfo {
    init(liveInfo: AtomicXCore.LiveInfo) {
        self.init()
        self.userID = liveInfo.liveOwner.userID
        self.liveID = liveInfo.liveID
        self.userName = liveInfo.liveOwner.userName
        self.avatarURL = liveInfo.liveOwner.avatarURL
    }
}

fileprivate extension String {
    static let connectionTitleText = internalLocalized("Start Co-hosting")
    static let connectedTitleText = internalLocalized("Connecting")
    static let recommendedTitleText = internalLocalized("Suggested Hosts")
    static let disconnectText = internalLocalized("End Co-host")

    static let disconnectAlertText = internalLocalized("Are you sure you want to disconnect from other streamers?")
    static let disconnectAlertCancelText = internalLocalized("Cancel")
    static let disconnectAlertDisconnectText = internalLocalized("End Co-host")

    static let confirmEndBattleText = internalLocalized("End PK")
    static let endBattleText = internalLocalized("Are you sure you want to end the battle? The current result will be the final result after the end")
    static let startCoHostText = internalLocalized("Start Co-hosting")
    static let inInviteText = internalLocalized("Inviting others you can withdraw the invitation and send a new one")
    static let inBattleText = internalLocalized("In Battle")
    static let requestBattleText = internalLocalized("Request Battle")
    static let requestTimeoutText = internalLocalized("Invitation has timed out")
}



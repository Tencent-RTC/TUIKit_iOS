//
//  ConnectionInvitePanel.swift
//  TUILiveKit
//
//  Created by jack on 2024/8/7.
//

import AtomicXCore
import Combine
import Foundation
import MJRefresh
import RTCCommon
import RTCRoomEngine
import TUICore

class AnchorCoHostManagerPanel: RTCBaseView {
    var onClickBack: (() -> ())?
    
    private let kCoHostTimeout: TimeInterval = 10
    private var cancellableSet: Set<AnyCancellable> = []
    
    private var recommendedUsers: [AnchorCoHostUserInfo] = []
    private var connectedUsers: [AnchorCoHostUserInfo] = []

    private let manager: AnchorManager
    
    private var lastApplyHashValue: Int?

    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .g7
        label.font = UIFont.customFont(ofSize: 20)
        label.text = .connectionTitleText
        return label
    }()
    
    private let disconnectButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = UIFont.customFont(ofSize: 14)
        button.setTitleColor(.warningTextColor, for: .normal)
        button.setTitle(.disconnectText, for: .normal)
        button.setImage(internalImage("live_connection_disconnect"), for: .normal)
        button.backgroundColor = .clear
        button.isHidden = true
        return button
    }()
    
    private lazy var backButton: UIButton = {
        let view = UIButton(type: .system)
        view.setBackgroundImage(internalImage("live_back_icon"), for: .normal)
        view.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        return view
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(AnchorCoHostUserCell.self, forCellReuseIdentifier: AnchorCoHostUserCell.identifier)
        tableView.register(AnchorCoHostUserTableHeaderView.self, forHeaderFooterViewReuseIdentifier: AnchorCoHostUserTableHeaderView.identifier)
        return tableView
    }()
    
    init(manager: AnchorManager) {
        self.manager = manager
        super.init(frame: .zero)
        backgroundColor = .g2
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshRoomListData()
    }
    
    override func constructViewHierarchy() {
        addSubview(backButton)
        addSubview(titleLabel)
        addSubview(disconnectButton)
        addSubview(tableView)
    }
    
    override func activateConstraints() {
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(20)
            make.top.equalToSuperview().inset(20)
            make.height.equalTo(24.scale375())
            make.width.equalTo(24.scale375())
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20.scale375Height())
        }
        disconnectButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(titleLabel)
        }
        
        tableView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(575.scale375Height())
            make.top.equalTo(titleLabel.snp.bottom)
        }
    }
    
    override func bindInteraction() {
        tableView.delegate = self
        tableView.dataSource = self
        addRefreshDataEvent()
        subscribeConnectionState()
        subscribeToastState()
        disconnectButton.addTarget(self, action: #selector(disconnect), for: .touchUpInside)
    }
    
    @objc private func backButtonClick(sender: UIButton) {
        onClickBack?()
    }
}

extension AnchorCoHostManagerPanel {
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
            let cursor = manager.liveListState.liveListCursor
            if cursor != "" {
                manager.liveListStore.fetchLiveList(cursor: cursor, count: 20, completion: nil)
                tableView.mj_footer?.endRefreshing()
            } else {
                tableView.mj_footer?.endRefreshingWithNoMoreData()
            }
        })
        footer.ignoredScrollViewContentInsetBottom = tableView.contentInset.bottom
        footer.setTitle(.loadingMoreText, for: .pulling)
        footer.setTitle(.loadingText, for: .refreshing)
        tableView.mj_footer = footer
    }
    
    private func refreshRoomListData() {
        tableView.reloadData()
        manager.liveListStore.fetchLiveList(cursor: "", count: 20, completion: nil)
    }
    
    private func subscribeConnectionState() {
        manager.subscribeState(StateSelector(keyPath: \AnchorCoHostState.connectedUsers))
            .removeDuplicates()
            .combineLatest(manager.subscribeState(StateSelector(keyPath: \AnchorCoHostState.recommendedUsers)).removeDuplicates(),
                           manager.subscribeState(StatePublisherSelector(keyPath: \LiveListState.liveListCursor)).removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] connected, recommended, cursor in
                guard let self = self else { return }
                if recommendedUsers.count > 0, cursor == "" {
                    tableView.mj_footer?.endRefreshingWithNoMoreData()
                } else {
                    tableView.mj_footer?.resetNoMoreData()
                }
                let liveID = manager.liveID
                connectedUsers = connected.filter { $0.liveID != liveID }
                recommendedUsers = recommended.filter { $0.liveID != liveID }
                disconnectButton.isHidden = connectedUsers.count <= 0
                tableView.reloadData()
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeToastState() {
        manager.toastSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                guard let self = self else { return }
                self.makeToast(message: message)
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Action

extension AnchorCoHostManagerPanel {
    @objc
    private func disconnect() {
        let alertInfo = AnchorAlertInfo(description: .disconnectAlertText,
                                        imagePath: nil,
                                        cancelButtonInfo: (String.disconnectAlertCancelText, .cancelTextColor),
                                        defaultButtonInfo: (String.disconnectAlertDisconnectText, .warningTextColor))
        { alertPanel in
            alertPanel.dismiss()
        } defaultClosure: { [weak self] alertPanel in
            guard let self = self else { return }
            manager.coHostStore.exitHostConnection()
            alertPanel.dismiss()
        }
        let alertPanel = AnchorAlertPanel(alertInfo: alertInfo)
        alertPanel.show()
    }
}

extension AnchorCoHostManagerPanel: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerId = AnchorCoHostUserTableHeaderView.identifier
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerId)
            as? AnchorCoHostUserTableHeaderView
        else {
            return nil
        }
        if section == 0, connectedUsers.count > 0 {
            headerView.titleLabel.text = .connectedTitleText + "(\(connectedUsers.count))"
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

extension AnchorCoHostManagerPanel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && connectedUsers.count > 0 {
            return connectedUsers.count
        }
        return recommendedUsers.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return connectedUsers.count > 0 ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AnchorCoHostUserCell.identifier, for: indexPath)
        if let connectionUserCell = cell as? AnchorCoHostUserCell {
            if indexPath.section == 0 && connectedUsers.count > 0 {
                connectionUserCell.updateUser(connectedUsers[indexPath.row])
            } else {
                connectionUserCell.updateUser(recommendedUsers[indexPath.row])
                connectionUserCell.inviteEventClosure = { [weak self] user in
                    guard let self = self else { return }
                    manager.willApplyingHost()
                    manager.coHostStore.requestHostConnection(targetHost: user.liveID, layoutTemplate: manager.pkTemplateMode.toPkAtomicType(), timeout: kCoHostTimeout) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .failure(let err):
                            manager.stopApplyingHost()
                            switch err.code {
                            case TUIConnectionCode.roomNotExist.rawValue,
                                 TUIConnectionCode.connecting.rawValue,
                                 TUIConnectionCode.connectingOtherRoom.rawValue,
                                 TUIConnectionCode.full.rawValue,
                                 TUIConnectionCode.retry.rawValue:
                                let error = InternalError(error: TUIConnectionCode(rawValue: err.code) ?? .unknown, message: err.message)
                                manager.onError(error)
                            default:
                                let error = InternalError(code: err.code, message: err.message)
                                manager.onError(error)
                            }
                        default: break
                        }
                    }
                    
                    if let value = lastApplyHashValue {
                        for item in cancellableSet.filter({ $0.hashValue == value }) {
                            item.cancel()
                            cancellableSet.remove(item)
                        }
                    }
                    
                    let publisher = manager.coHostStore.coHostEventPublisher
                        .receive(on: RunLoop.main)
                        .sink { [weak self] event in
                            guard let self = self else { return }
                            switch event {
                            case .onCoHostRequestAccepted(invitee: _),
                                 .onCoHostRequestRejected(invitee: _),
                                 .onCoHostRequestTimeout(inviter: _, invitee: _):
                                manager.stopApplyingHost()
                            default: break
                            }
                        }
                    publisher.store(in: &cancellableSet)
                    lastApplyHashValue = publisher.hashValue
                }
            }
        }
        return cell
    }
}

private extension String {
    static let connectionTitleText = internalLocalized("Start Co-hosting")
    static let connectedTitleText = internalLocalized("Connecting")
    static let recommendedTitleText = internalLocalized("Suggested Hosts")
    static let disconnectText = internalLocalized("End Co-host")
    
    static let disconnectAlertText = internalLocalized("Are you sure you want to disconnect from other streamers?")
    static let disconnectAlertCancelText = internalLocalized("Cancel")
    static let disconnectAlertDisconnectText = internalLocalized("End Co-host")
}

//
//  ConnectionInvitePanel.swift
//  TUILiveKit
//
//  Created by jack on 2024/8/7.
//

import AtomicX
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

    private let store: AnchorStore
    
    private var lastApplyHashValue: Int?
    
    private let titleLabel: AtomicLabel = {
        let label = AtomicLabel(.connectionTitleText) { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Medium16)
        }
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
    
    init(store: AnchorStore) {
        self.store = store
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
            let cursor = store.coHostState.candidatesCursor
            if cursor != "" {
                store.coHostStore.getCoHostCandidates(cursor: cursor, completion: nil)
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
        store.coHostStore.getCoHostCandidates(cursor: "", completion: nil)
    }
    
    private func subscribeConnectionState() {
        store.subscribeState(StateSelector(keyPath: \AnchorCoHostState.connectedUsers))
            .removeDuplicates()
            .combineLatest(store.subscribeState(StateSelector(keyPath: \AnchorCoHostState.recommendedUsers)).removeDuplicates(),
                           store.subscribeState(StatePublisherSelector(keyPath: \CoHostState.candidatesCursor)).removeDuplicates())
            .receive(on: RunLoop.main)
            .sink { [weak self] connected, recommended, cursor in
                guard let self = self else { return }
                if recommendedUsers.count > 0, cursor == "" {
                    tableView.mj_footer?.endRefreshingWithNoMoreData()
                } else {
                    tableView.mj_footer?.resetNoMoreData()
                }
                let liveID = store.liveID
                connectedUsers = connected.filter { $0.userInfo.liveID != liveID }
                recommendedUsers = recommended.filter { $0.userInfo.liveID != liveID }
                disconnectButton.isHidden = connectedUsers.count <= 0
                tableView.reloadData()
            }
            .store(in: &cancellableSet)
    }
    
    private func subscribeToastState() {
        store.toastSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] message, style in
                guard let self = self else { return }
                self.showAtomicToast(text: message, style: style)
            }
            .store(in: &cancellableSet)
    }
}

// MARK: - Action

extension AnchorCoHostManagerPanel {
    @objc
    private func disconnect() {
        let cancelButton = AlertButtonConfig(text: String.disconnectAlertCancelText, type: .grey) { alertView in
            alertView.dismiss()
        }
        let confirmButton = AlertButtonConfig(text: String.disconnectAlertDisconnectText, type: .red) { [weak self] alertView in
            guard let self = self else { return }
            store.coHostStore.exitHostConnection()
            alertView.dismiss()
        }
        let alertConfig = AlertViewConfig(title: .disconnectAlertText, cancelButton: cancelButton, confirmButton: confirmButton)
        let alertView = AtomicAlertView(config: alertConfig)
        alertView.show()
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
                    store.willApplyingHost()
                    store.coHostStore.requestHostConnection(targetHost: user.userInfo.liveID, layoutTemplate: store.pkTemplateMode.toPkAtomicType(), timeout: kCoHostTimeout) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .failure(let err):
                            store.stopApplyingHost()
                            switch err.code {
                            case TUIConnectionCode.roomNotExist.rawValue,
                                 TUIConnectionCode.connecting.rawValue,
                                 TUIConnectionCode.connectingOtherRoom.rawValue,
                                 TUIConnectionCode.full.rawValue,
                                 TUIConnectionCode.retry.rawValue,
                                 TUIConnectionCode.roomMismatch.rawValue:
                                let error = InternalError(error: TUIConnectionCode(rawValue: err.code) ?? .unknown, message: err.message)
                                store.onError(error)
                            default:
                                let error = InternalError(code: err.code, message: err.message)
                                store.onError(error)
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
                    
                    let publisher = store.coHostStore.coHostEventPublisher
                        .receive(on: RunLoop.main)
                        .sink { [weak self] event in
                            guard let self = self else { return }
                            switch event {
                            case .onCoHostRequestAccepted(invitee: _),
                                 .onCoHostRequestRejected(invitee: _),
                                 .onCoHostRequestTimeout(inviter: _, invitee: _):
                                store.stopApplyingHost()
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
    static let disconnectText = internalLocalized("Exit connect")
    
    static let disconnectAlertText = internalLocalized("Are you sure you want to disconnect from other streamers?")
    static let disconnectAlertCancelText = internalLocalized("Cancel")
    static let disconnectAlertDisconnectText = internalLocalized("End Co-host")
}

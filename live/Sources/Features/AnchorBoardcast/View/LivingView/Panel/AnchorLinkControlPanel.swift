//
//  AnchorLinkControlPanel.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/10/25.
//

import AtomicXCore
import Combine
import Foundation
import RTCCommon
import AtomicX

class AnchorLinkControlPanel: UIView {
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private weak var coreView: LiveCoreView?
    private var cancellable = Set<AnyCancellable>()
    private var isPortrait: Bool {
        WindowUtils.isPortrait
    }

    private var linkingList: [SeatUserInfo] = []
    private var applyList: [LiveUserInfo] = []
    private lazy var backButton: UIButton = {
        let view = UIButton(type: .system)
        view.setBackgroundImage(internalImage("live_back_icon", rtlFlipped: true), for: .normal)
        view.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        return view
    }()

    private let titleLabel: AtomicLabel = {
        let label = AtomicLabel(.anchorLinkControlTitle) { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Medium16)
        }
        label.contentMode = .center
        label.sizeToFit()
        return label
    }()
    
    private lazy var userListTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.register(LinkMicBaseCell.self, forCellReuseIdentifier: LinkMicBaseCell.cellReuseIdentifier)
        tableView.register(UserRequestLinkCell.self, forCellReuseIdentifier: UserRequestLinkCell.cellReuseIdentifier)
        tableView.register(UserLinkCell.self, forCellReuseIdentifier: UserLinkCell.cellReuseIdentifier)
        return tableView
    }()

    init(store: AnchorStore, routerManager: AnchorRouterManager, coreView: LiveCoreView) {
        self.store = store
        self.routerManager = routerManager
        self.coreView = coreView
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        backgroundColor = .clear
        constructViewHierarchy()
        activateConstraints()
        subscribeSeatState()
    }

    private func subscribeSeatState() {
        store.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.applicants))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] seatApplicationList in
                guard let self = self else { return }
                applyList = seatApplicationList
                userListTableView.reloadData()
            }
            .store(in: &cancellable)
        store.subscribeState(StatePublisherSelector(keyPath: \CoGuestState.connected))
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self = self else { return }
                let selfUserId = store.selfUserID
                linkingList = connected.filter { $0.userID != selfUserId }
                userListTableView.reloadData()
            }
            .store(in: &cancellable)

        store.toastSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] message,style in
                guard let self = self else { return }
                showAtomicToast(text: message, style: style)
            }
            .store(in: &cancellable)
    }
}

// MARK: Layout

extension AnchorLinkControlPanel {
    func constructViewHierarchy() {
        backgroundColor = .g2
        layer.cornerRadius = 16
        layer.masksToBounds = true
        addSubview(backButton)
        addSubview(titleLabel)
        addSubview(userListTableView)
    }

    func activateConstraints() {
        snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }

        backButton.snp.remakeConstraints { make in
            make.leading.equalToSuperview().inset(20)
            make.top.equalToSuperview().inset(20)
            make.height.equalTo(24.scale375())
            make.width.equalTo(24.scale375())
        }

        titleLabel.snp.remakeConstraints { make in
            make.centerY.equalTo(backButton)
            make.centerX.equalToSuperview()
            make.height.equalTo(24.scale375())
        }

        userListTableView.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.height.equalTo(screenHeight * 2 / 3)
        }
    }
}

// MARK: Action

extension AnchorLinkControlPanel {
    @objc func backButtonClick(sender: UIButton) {
        routerManager.router(action: .dismiss())
    }
}

extension AnchorLinkControlPanel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return linkingList.count
        } else if section == 1 {
            return applyList.count
        } else {
            return 0
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
}

extension AnchorLinkControlPanel: UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            return configureUserLinkCell(for: indexPath, in: tableView)
        case 1:
            return configureUserRequestLinkCell(for: indexPath, in: tableView)
        default:
            return tableView.dequeueReusableCell(withIdentifier: LinkMicBaseCell.cellReuseIdentifier, for: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.scale375()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 20.scale375Height()))
        headerView.backgroundColor = .g2
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorSecondary,
                            font: theme.typography.Regular14)
        }
        label.frame = CGRect(x: 24, y: 0, width: headerView.frame.width - 48, height: headerView.frame.height)
        if section == 0 {
            label.text = .localizedReplace(.anchorLinkControlSeatCount, replace: String(linkingList.count))
        } else if section == 1 {
            label.text = .localizedReplace(.anchorLinkControlRequestCount,
                                           replace: "\(applyList.count)")
        }
        headerView.addSubview(label)
        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 && linkingList.count > 0 {
            return 20.scale375Height()
        }

        if section == 1 && applyList.count > 0 {
            return 20.scale375Height()
        }

        return 0
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0, linkingList.count > 0 {
            let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 7.0))
            footerView.backgroundColor = .g3.withAlphaComponent(0.1)
            return footerView
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0, linkingList.count > 0 {
            return 7.scale375Height()
        } else {
            return 0
        }
    }

    private func configureUserLinkCell(for indexPath: IndexPath, in tableView: UITableView) -> UITableViewCell {
        guard indexPath.row < linkingList.count,
              let cell = tableView.dequeueReusableCell(withIdentifier: UserLinkCell.cellReuseIdentifier, for: indexPath) as? UserLinkCell
        else {
            return tableView.dequeueReusableCell(withIdentifier: LinkMicBaseCell.cellReuseIdentifier, for: indexPath)
        }

        cell.kickoffEventClosure = { [weak self] seatInfo in
            guard let self = self else { return }
            store.seatStore.kickUserOutOfSeat(userID: seatInfo.userID) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let err):
                    let error = InternalError(code: err.code, message: err.message)
                    store.onError(error)
                default: break
                }
            }
        }

        cell.seatInfo = linkingList[indexPath.row]
        cell.lineView.isHidden = (linkingList.count - 1) == indexPath.row
        return cell
    }

    private func configureUserRequestLinkCell(for indexPath: IndexPath, in tableView: UITableView) -> UITableViewCell {
        guard indexPath.row < applyList.count,
              let cell = tableView.dequeueReusableCell(withIdentifier: UserRequestLinkCell.cellReuseIdentifier, for: indexPath) as? UserRequestLinkCell
        else {
            return tableView.dequeueReusableCell(withIdentifier: LinkMicBaseCell.cellReuseIdentifier, for: indexPath)
        }

        cell.respondEventClosure = { [weak self] seatApplication, isAccepted, onComplete in
            guard let self = self else { return }
            if isAccepted {
                store.coGuestStore.acceptApplication(userID: seatApplication.userID) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(()):
                        onComplete()
                    case .failure(let err):
                        let error = InternalError(code: err.code, message: err.message)
                        store.onError(error)
                        onComplete()
                    }
                }
            } else {
                store.coGuestStore.rejectApplication(userID: seatApplication.userID) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(()):
                        onComplete()
                    case .failure(let err):
                        let error = InternalError(code: err.code, message: err.message)
                        store.onError(error)
                        onComplete()
                    }
                }
            }
        }

        cell.seatApplication = applyList[indexPath.row]
        return cell
    }
}

private extension String {
    static var anchorLinkControlTitle: String {
        internalLocalized("common_link_mic_manager")
    }

    static var anchorLinkControlDesc: String {
        internalLocalized("common_enable_audience_request_link")
    }

    static var anchorLinkControlSeatCount: String {
        internalLocalized("common_seat_list_title")
    }

    static var anchorLinkControlRequestCount: String {
        internalLocalized("common_seat_application_title")
    }
}

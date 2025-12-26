//
//  CoGuestView.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/25.
//

import Foundation
import Kingfisher
import Combine
import RTCCommon
import AtomicXCore

class AnchorCoGuestView: UIView {
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private var cancellableSet = Set<AnyCancellable>()
    private var isViewReady: Bool = false
    private var seatInfo: SeatInfo
    
    init(seatInfo: SeatInfo, store: AnchorStore, routerManager: AnchorRouterManager) {
        self.seatInfo = seatInfo
        self.store = store
        self.routerManager = routerManager
        super.init(frame: .zero)
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGestureRecognizer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        subscribeState()
        initViewState()
    }
    
    private lazy var userInfoView = AnchorUserStatusView(seatInfo: seatInfo, store: store)
    
    private func constructViewHierarchy() {
        addSubview(userInfoView)
    }

    private func activateConstraints() {
        userInfoView.snp.makeConstraints { make in
            make.height.equalTo(18)
            make.bottom.equalToSuperview().offset(-5)
            make.leading.equalToSuperview().offset(5)
            make.width.lessThanOrEqualTo(self).multipliedBy(0.9)
        }
    }
    
    private func initViewState() {
        if store.coHostState.connected.count > 1 || store.coGuestState.connected.count > 1 {
            userInfoView.isHidden = false
        } else {
            userInfoView.isHidden = true
        }
    }
    
    @objc private func handleTap() {
        let isSelfOwner = store.selfUserID == store.liveListState.currentLive.liveOwner.userID
        let isSelfView = store.selfUserID == seatInfo.userInfo.userID
        let isOnlyUserOnSeat = store.coGuestState.connected.count == 1
        if !isSelfOwner && isOnlyUserOnSeat && !isSelfView { return }
        let type: AnchorUserManagePanelType = !isSelfOwner && !isSelfView ? .userInfo : .mediaAndSeat
        routerManager.router(action: .present(.userManagement(seatInfo, type: type)))
    }
}

extension AnchorCoGuestView {
    func subscribeState() {
        FloatWindow.shared.subscribeShowingState()
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isShow in
                guard let self = self else { return }
                isHidden = isShow
            }
            .store(in: &cancellableSet)
    }
}

//
//  AudienceCoHostView.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2024/11/25.
//

import Foundation
import AtomicX
import Combine
import AtomicXCore

class AudienceCoHostView: UIView {
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager?
    private var isViewReady: Bool = false
    private var seatInfo: SeatInfo
    private var cancellableSet = Set<AnyCancellable>()
    
    init(seatInfo: SeatInfo, manager: AudienceStore, routerManager: AudienceRouterManager? = nil) {
        self.seatInfo = seatInfo
        self.manager = manager
        self.routerManager = routerManager
        super.init(frame: .zero)
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
        initViewState()
        subscribeState()
        self.isUserInteractionEnabled = (routerManager != nil)
        addTapGestureIfNeeded()
    }
    
    private lazy var userInfoView = AudienceUserStatusView(seatInfo: seatInfo, manager: manager)
    
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
        updateUserInfoVisibility(coHostCount: manager.coHostState.connected.count)
    }

    private func updateUserInfoVisibility(coHostCount: Int) {
        userInfoView.isHidden = !(coHostCount > 1)
    }
    
    private func addTapGestureIfNeeded() {
        guard routerManager != nil else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }
    
    @objc private func handleTap() {
        
        guard isViewReady, !isHidden, window != nil,
              bounds.width > 0, bounds.height > 0 else {
            return
        }
        
        guard let routerManager = routerManager else {
            return
        }

        if seatInfo.userInfo.userID == manager.loginState.loginUserInfo?.userID {
            return
        }
        let panel = CoHostAnchorInfoView(seatInfo: seatInfo, manager: manager, routerManager: routerManager)
        routerManager.present(view: panel, config: .bottomDefault())
    }
}

extension AudienceCoHostView {
    func subscribeState() {
        let coHostConnectedPublisher = manager.subscribeState(StatePublisherSelector(keyPath: \CoHostState.connected))

        coHostConnectedPublisher
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] connectedUsers in
                guard let self = self else { return }
                self.updateUserInfoVisibility(coHostCount: connectedUsers.count)
            }
            .store(in: &cancellableSet)


        Publishers.CombineLatest(coHostConnectedPublisher, FloatWindow.shared.subscribeShowingState())
            .receive(on: RunLoop.main)
            .removeDuplicates { $0.0 == $1.0 && $0.1 == $1.1 }
            .sink { [weak self] connectedUsers, isFloatShow in
                guard let self = self else { return }
                self.isHidden = connectedUsers.isEmpty || isFloatShow
            }
            .store(in: &cancellableSet)
    }
}

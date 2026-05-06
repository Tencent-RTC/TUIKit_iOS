//
//  AnchorTopRightView.swift
//  TUILiveKit
//
//  Created on 2026/3/10.
//

import UIKit
import AtomicX
import SnapKit
import AtomicXCore
import Combine
import RTCRoomEngine

class AnchorTopRightView: UIView {
    private let store: AnchorStore
    private let routerManager: AnchorRouterManager
    private var cancellableSet: Set<AnyCancellable> = []
    
    private var customWrappers: [UIView] = []

    // MARK: - Built-in Views

    private let itemHeight: CGFloat = 24.scale375()

    private lazy var closeButton: UIButton = {
        let view = UIButton(frame: .zero)
        view.setImage(internalImage("live_end_live_icon"), for: .normal)
        view.addTarget(self, action: #selector(closeButtonClick), for: .touchUpInside)
        view.imageEdgeInsets = UIEdgeInsets(top: 2.scale375(), left: 2.scale375(), bottom: 2.scale375(), right: 2.scale375())
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalTo: view.heightAnchor),
        ])
        return view
    }()

    private lazy var floatWindowButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(internalImage("live_floatwindow_open_icon"), for: .normal)
        button.addTarget(self, action: #selector(onFloatWindowButtonClick), for: .touchUpInside)
        button.imageEdgeInsets = UIEdgeInsets(top: 2.scale375(), left: 2.scale375(), bottom: 2.scale375(), right: 2.scale375())
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalTo: button.heightAnchor),
        ])
        return button
    }()

    private lazy var audienceListView: AudienceListView = {
        let view = AudienceListView()
        view.onUserManageButtonClicked = { [weak self] user in
            guard let self = self else { return }
            let panel = AnchorUserManagePanelView(user: user, store: store, routerManager: routerManager, type: .messageAndKickOut)
            routerManager.present(view: panel, config: .bottomDefault())
        }
        return view
    }()

    // MARK: - Init

    init(store: AnchorStore, routerManager: AnchorRouterManager) {
        self.store = store
        self.routerManager = routerManager
        super.init(frame: .zero)
        backgroundColor = .clear
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func bindInteraction() {
        subscribeState()
    }
    
    private func subscribeState() {
        store.subscribeState(StatePublisherSelector(keyPath: \LiveListState.currentLive))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] currentLive in
                guard let self = self else { return }
                if !currentLive.isEmpty {
                    audienceListView.initialize(liveId: currentLive.liveID)
                }
            }
            .store(in: &cancellableSet)
    }
    

    // MARK: - Public
    func updateItems(_ items: [AnchorTopRightItem]) {
        for wrapper in customWrappers {
            wrapper.removeFromSuperview()
        }
        customWrappers.removeAll()

        audienceListView.isHidden = true
        floatWindowButton.isHidden = true
        closeButton.isHidden = true

        var visibleViews: [UIView] = []
        for item in items.reversed() {
            switch item {
            case .audienceCount:
                audienceListView.isHidden = false
                visibleViews.append(audienceListView)
            case .floatWindow:
                floatWindowButton.isHidden = false
                visibleViews.append(floatWindowButton)
            case .close:
                closeButton.isHidden = false
                visibleViews.append(closeButton)
            case .custom(let customView):
                let wrapper = wrapCustomView(customView)
                addSubview(wrapper)
                customWrappers.append(wrapper)
                visibleViews.append(wrapper)
            }
        }

        relayoutItems(visibleViews)
    }

    private func wrapCustomView(_ customView: UIView) -> UIView {
        let wrapper = UIView()
        wrapper.backgroundColor = .clear
        customView.removeFromSuperview()
        wrapper.addSubview(customView)
        customView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        return wrapper
    }

    // MARK: - Semantic Action API

    func showAudienceList() {
        audienceListView.containerTapAction()
    }

    func requestFloatWindow() {
        store.floatWindowSubject.send()
    }

    func requestEndLive() {
        closeButtonClick()
    }

    // MARK: - Layout

    private func constructViewHierarchy() {
        addSubview(closeButton)
        addSubview(floatWindowButton)
        addSubview(audienceListView)
    }

    private func activateConstraints() {
        relayoutItems([audienceListView, floatWindowButton, closeButton])
    }

    private func relayoutItems(_ views: [UIView]) {
        guard !views.isEmpty else { return }

        let spacing = 8.scale375()

        for (index, view) in views.enumerated() {
            view.snp.remakeConstraints { make in
                if index == 0 {
                    make.trailing.equalToSuperview()
                } else {
                    make.trailing.equalTo(views[index - 1].snp.leading).offset(-spacing)
                }
                make.height.equalTo(itemHeight)
                make.top.bottom.equalToSuperview()

                if index == views.count - 1 {
                    make.leading.equalToSuperview()
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func closeButtonClick() {
        store.endLiveRequestSubject.send()
    }

    @objc private func onFloatWindowButtonClick() {
        store.floatWindowSubject.send()
    }
}

// MARK: - Localized Strings

private extension String {
    static let confirmCloseText = internalLocalized("common_end_live")
    static let confirmEndLiveText = internalLocalized("live_end_live_tips")
    static let confirmExitText = internalLocalized("common_exit_live")

    static let endLiveOnConnectionText = internalLocalized("common_end_connection_tips")
    static let endLiveDisconnectText = internalLocalized("common_end_connection")
    static let endLiveOnLinkMicText = internalLocalized("common_anchor_end_link_tips")
    static let endLiveOnBattleText = internalLocalized("common_end_pk_tips")
    static let endLiveBattleText = internalLocalized("common_end_pk")
    static let cancelText = internalLocalized("common_cancel")
}

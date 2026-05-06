//
//  AudienceTopRightView.swift
//  TUILiveKit
//
//  Created on 2026/3/14.
//

import UIKit
import AtomicX
import SnapKit
import AtomicXCore
import Combine
import RTCRoomEngine

class AudienceTopRightView: UIView {
    private let manager: AudienceStore
    private let routerManager: AudienceRouterManager
    private var cancellableSet: Set<AnyCancellable> = []

    private var customWrappers: [UIView] = []

    // MARK: - Built-in Views

    private let itemHeight: CGFloat = 24.scale375()

    private lazy var closeButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.setImage(internalImage("live_leave_icon"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 2.scale375(), left: 2.scale375(), bottom: 2.scale375(), right: 2.scale375())
        button.addTarget(self, action: #selector(onCloseButtonClick), for: .touchUpInside)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalTo: button.heightAnchor),
        ])
        return button
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
        return view
    }()

    #if RTCube_APPSTORE
    private lazy var reportBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setImage(internalImage("live_report"), for: .normal)
        btn.imageView?.contentMode = .scaleAspectFill
        btn.addTarget(self, action: #selector(clickReport), for: .touchUpInside)
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalTo: btn.heightAnchor),
        ])
        return btn
    }()
    #endif

    // MARK: - Init

    init(manager: AudienceStore, routerManager: AudienceRouterManager) {
        self.manager = manager
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

    // MARK: - Binding

    private func bindInteraction() {
        subscribeState()
    }

    private func subscribeState() {
        manager.subscribeState(StatePublisherSelector(keyPath: \LiveListState.currentLive))
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

    func updateItems(_ items: [AudienceTopRightItem]) {
        for wrapper in customWrappers {
            for subview in wrapper.subviews {
                subview.snp.removeConstraints()
            }
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

        #if RTCube_APPSTORE
        visibleViews.append(reportBtn)
        #endif

        relayoutItems(visibleViews)
    }

    // MARK: - Semantic Action API

    func showAudienceList() {
        audienceListView.containerTapAction()
    }

    func requestFloatWindow() {
        onFloatWindowButtonClick()
    }

    func requestExitLive() {
        manager.exitLiveRequestSubject.send()
    }
    
    // MARK: - Layout

    private func constructViewHierarchy() {
        addSubview(closeButton)
        addSubview(floatWindowButton)
        addSubview(audienceListView)
        #if RTCube_APPSTORE
        addSubview(reportBtn)
        #endif
    }

    private func activateConstraints() {
        var defaultViews: [UIView] = [audienceListView, floatWindowButton, closeButton]
        #if RTCube_APPSTORE
        defaultViews.append(reportBtn)
        #endif
        relayoutItems(defaultViews)
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
                make.top.bottom.equalToSuperview()
                make.height.equalTo(itemHeight)

                if index == views.count - 1 {
                    make.leading.equalToSuperview()
                }
            }
        }
    }

    // MARK: - Slide to Clear

    func applyClearTranslation(_ translationX: CGFloat) {
        let transform: CGAffineTransform = translationX == 0 ? .identity : CGAffineTransform(translationX: translationX, y: 0)
        audienceListView.transform = transform
        floatWindowButton.transform = transform
        for wrapper in customWrappers {
            wrapper.transform = transform
        }
        #if RTCube_APPSTORE
        reportBtn.transform = transform
        #endif
        // Ensure closeButton is above its siblings so sliding views don't obscure it.
        if translationX != 0 {
            bringSubviewToFront(closeButton)
        }
    }

    // MARK: - Actions

    @objc private func onFloatWindowButtonClick() {
        manager.floatWindowSubject.send()
    }

    @objc private func onCloseButtonClick() {
        manager.exitLiveRequestSubject.send()
    }

    #if RTCube_APPSTORE
    @objc private func clickReport() {
        let selector = NSSelectorFromString("showReportAlertWithRoomId:ownerId:")
        if responds(to: selector) {
            perform(selector, with: manager.liveID, with: manager.liveListState.currentLive.liveOwner.userID)
        }
    }
    #endif
}

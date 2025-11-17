//
//  VRTopView.swift
//  TUILiveKit
//
//  Created by aby on 2024/3/13.
//

import UIKit
import SnapKit
import Kingfisher
import Combine
import AtomicXCore
import RTCRoomEngine

private let containerHeight = 36.0
private let componentHeight = 32.0

protocol VRTopViewDelegate: AnyObject {
    func topView(_ topView: VRTopView, tap event: VRTopView.TapEvent, sender: Any?) -> Void
}

class VRTopView: UIView {
    
    enum TapEvent {
        case stop
        case audienceList
        case roomInfo
    }
    
    private var routerManager: VRRouterManager
    private let isOwner: Bool
    private var liveId: String?
    var cancellableSet: Set<AnyCancellable> = []
    
    weak var delegate: VRTopViewDelegate?
   
    private let liveInfoView: LiveInfoView = {
        let view = LiveInfoView()
        view.mm_h = Int(componentHeight).scale375()
        view.backgroundColor = UIColor.g2.withAlphaComponent(0.4)
        view.layer.cornerRadius = view.mm_h * 0.5
        return view
    }()
    
    private let audienceListView: AudienceListView = {
        let view = AudienceListView()
        return view
    }()
    
    private lazy var reportBtn: UIButton  = {
        let btn = UIButton(type: .custom)
        btn.setImage(internalImage("live_report"), for: .normal)
        btn.imageView?.contentMode = .scaleAspectFill
        btn.addTarget(self, action: #selector(clickReport), for: .touchUpInside)
        return btn
    }()
    
    private lazy var stopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setBackgroundImage(internalImage( self.isOwner ? "live_end_live_icon" : "live_leave_icon"), for: .normal)
        return button
    }()
    
    init(routerManager: VRRouterManager,isOwner: Bool) {
        self.routerManager = routerManager
        self.isOwner = isOwner
        super.init(frame: .zero)
    }
    
    func initialize(roomId: String) {
        liveId = roomId
        let liveInfo = LiveListStore.shared.state.value.currentLive
        liveInfoView.initialize(liveInfo: liveInfo)
        audienceListView.initialize(liveId: roomId)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("deinit \(type(of: self))")
    }

    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activeViewConstraint()
        bindInteraction()
        isViewReady = true
    }
    
    private func constructViewHierarchy() {
        addSubview(liveInfoView)
        addSubview(audienceListView)
        addSubview(stopButton)
#if RTCube_APPSTORE
        addSubview(reportBtn)
#endif
    }
    
    private func activeViewConstraint() {
        liveInfoView.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()
            make.height.equalTo(liveInfoView.mm_h)
            make.leading.equalToSuperview().inset(16.scale375())
            make.top.bottom.equalToSuperview()
        }
#if RTCube_APPSTORE
        reportBtn.snp.makeConstraints({ make in
            make.centerY.equalTo(stopButton)
            make.right.equalTo(stopButton.snp.left).offset(-8)
            make.width.height.equalTo(24.scale375Width())
        })
        audienceListView.snp.remakeConstraints { make in
            make.centerY.equalTo(stopButton)
            make.trailing.equalTo(reportBtn.snp.leading).offset(-4.scale375())
            make.leading.greaterThanOrEqualTo(liveInfoView.snp.trailing).offset(20.scale375())
        }
#else
        audienceListView.snp.remakeConstraints { make in
            make.centerY.equalTo(stopButton)
            make.trailing.equalTo(stopButton.snp.leading).offset(-4.scale375())
            make.leading.greaterThanOrEqualTo(liveInfoView.snp.trailing).offset(20.scale375())
        }
#endif
        stopButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(24.scale375())
            make.width.equalTo(24.scale375())
        }
    }
    
    private func bindInteraction() {
        stopButton.addTarget(self, action: #selector(buttonTouchUpInSide(sender:)), for: .touchUpInside)
    
        let liveInfoViewTap = UITapGestureRecognizer(target: self, action: #selector(liveInfoViewTap(sender:)))
        liveInfoView.addGestureRecognizer(liveInfoViewTap)
    }
}

extension VRTopView {
    @objc
    private func buttonTouchUpInSide(sender: UIButton) {
        self.delegate?.topView(self, tap: .stop, sender: sender)
    }
    
    @objc func liveInfoViewTap(sender: UITapGestureRecognizer) {
        self.delegate?.topView(self, tap: .roomInfo, sender: sender)
    }
    
    @objc
    private func clickReport() {
        let selector = NSSelectorFromString("showReportAlertWithRoomId:ownerId:")
        if responds(to: selector) {
            perform(selector, with: liveId ?? "", with: LiveListStore.shared.state.value.currentLive.liveOwner.userID)
        }
    }
}

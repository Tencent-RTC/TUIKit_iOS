//
//  RoomBottomBarView.swift
//  TUIRoomKit
//
//  Created on 2025/11/21.
//  Copyright © 2025 Tencent. All rights reserved.
//

import AtomicXCore
import Combine

public protocol RoomBottomBarViewDelegate: AnyObject {
    func onMembersButtonTapped()
    func onHandsUpManagerButtonTapped()
}

let buttonItemSizeForStandard: CGFloat = 52
let buttonItemSizeForWebinar: CGFloat = 40

// MARK: - RoomBottomBarView Component
public class RoomBottomBarView: UIView, BaseView {
    // MARK: - BaseView Properties
    public weak var routerContext: RouterContext?
    
    // MARK: - Properties
    public weak var delegate: RoomBottomBarViewDelegate?
    
    private let roomID: String
    private let roomType: RoomType
    
    // MARK: - UI Components
    private lazy var standardBottomBarView: StandardRoomBottomBarView = {
        let view = StandardRoomBottomBarView(roomID: roomID)
        return view
    }()
    
    private lazy var webinarBottomBarView: WebinarRoomBottomBarView = {
        let view = WebinarRoomBottomBarView(roomID: roomID)
        return view
    }()
    
    // MARK: - Initialization
    public init(roomID: String, roomType: RoomType) {
        self.roomID = roomID
        self.roomType = roomType
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    public func setupViews() {
        switch roomType {
        case .standard:
            addSubview(standardBottomBarView)
        case .webinar:
            addSubview(webinarBottomBarView)
        }
    }
    
    public func setupConstraints() {
        switch roomType {
        case .standard:
            standardBottomBarView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        case .webinar:
            webinarBottomBarView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
    
    public func setupStyles() {}
    
    public func setupBindings() {
        switch roomType {
        case .standard:
            standardBottomBarView.delegate = self
        case .webinar:
            webinarBottomBarView.delegate = self
        }
    }
}

extension RoomBottomBarView: StandardRoomBottomBarViewDelegate {
    public func onMembersButtonTapped(bottomBar: StandardRoomBottomBarView) {
        delegate?.onMembersButtonTapped()
    }
}

extension RoomBottomBarView: WebinarRoomBottomBarViewDelegate {
    public func onMembersButtonTapped(bottomBar: WebinarRoomBottomBarView) {
        delegate?.onMembersButtonTapped()
    }
    
    public func onHandsUpManagerButtonTapped(bottomBar: WebinarRoomBottomBarView) {
        delegate?.onHandsUpManagerButtonTapped()
    }
}

//
//  ParticipantListView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2025/11/25.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SnapKit
import AtomicXCore

public protocol ParticipantListViewDelegate: AnyObject {
    func muteAllAudioButtonTapped(disable: Bool)
    func muteAllVideoButtonTapped(disable: Bool)
    func participantTapped(view: ParticipantListView, participant: RoomParticipant, isAudience: Bool)
}

// MARK: - ParticipantListContent
protocol ParticipantListContentActionDelegate: AnyObject {
    func participantListContentRequestDismiss()
    func participantListContent(muteAllAudioDisable disable: Bool)
    func participantListContent(muteAllVideoDisable disable: Bool)
    func participantListContent(didTap participant: RoomParticipant, isAudience: Bool)
}

protocol ParticipantListContent: AnyObject {
    var actionDelegate: ParticipantListContentActionDelegate? { get set }
}

// MARK: - ParticipantListView
public class ParticipantListView: UIView, BasePanel, PanelHeightProvider {

    // MARK: - BasePanel Properties
    weak public var parentView: UIView?
    weak public var backgroundMaskView: PanelMaskView?

    // MARK: - PanelHeightProvider
    public var panelHeight: CGFloat {
        return UIScreen.main.bounds.height * 0.8
    }

    public weak var delegate: ParticipantListViewDelegate?

    // MARK: - Properties
    private let roomID: String
    private let roomType: RoomType

    private lazy var contentView: UIView & ParticipantListContent = {
        let view: UIView & ParticipantListContent = roomType == .standard
            ? StandardParticipantListView(roomID: roomID)
            : WebinarParticipantListView(roomID: roomID)
        view.actionDelegate = self
        return view
    }()

    // MARK: - Initialization
    public init(roomID: String, roomType: RoomType) {
        self.roomID = roomID
        self.roomType = roomType
        super.init(frame: .zero)
        backgroundColor = .clear
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - ParticipantListContentActionDelegate
extension ParticipantListView: ParticipantListContentActionDelegate {
    func participantListContentRequestDismiss() {
        dismiss()
    }

    func participantListContent(muteAllAudioDisable disable: Bool) {
        delegate?.muteAllAudioButtonTapped(disable: disable)
    }

    func participantListContent(muteAllVideoDisable disable: Bool) {
        delegate?.muteAllVideoButtonTapped(disable: disable)
    }

    func participantListContent(didTap participant: RoomParticipant, isAudience: Bool) {
        delegate?.participantTapped(view: self, participant: participant, isAudience: isAudience)
    }
}

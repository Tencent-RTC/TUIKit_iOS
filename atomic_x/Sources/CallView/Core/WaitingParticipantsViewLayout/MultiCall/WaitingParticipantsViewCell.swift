//
//  WaitingParticipantsViewCell.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import Foundation
import AtomicXCore
import SnapKit

class WaitingParticipantsViewCell: UICollectionViewCell {
    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Private
    private var participant: CallParticipantInfo = CallParticipantInfo()
    private let participantIcon = {
        let imageView = UIImageView(frame: CGRect.zero)
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 2.0
        if let image = CallKitBundle.getBundleImage(name: "default_participant_icon") {
            imageView.image = image
        }
        return imageView
    }()
    
    // MARK: UI Specification Processing
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }
}

// MARK: Layout
extension WaitingParticipantsViewCell {
    private func constructViewHierarchy() {
        contentView.addSubview(participantIcon)
    }
    
    private func activateConstraints() {
        participantIcon.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.top)
            make.leading.equalTo(contentView.snp.leading)
            make.trailing.equalTo(contentView.snp.trailing)
            make.bottom.equalTo(contentView.snp.bottom)
        }
    }
    
    func initCell(participant: CallParticipantInfo) {
        self.participant = participant
        setParticipantIcon()
    }
    
    private func setParticipantIcon() {
        let participantImage: UIImage? = CallKitBundle.getBundleImage(name: "default_participant_icon")
        if participant.avatarURL == "" {
            participantIcon.image = participantImage ?? nil
        } else {
            participantIcon.sd_setImage(with: URL(string: participant.avatarURL), placeholderImage: participantImage)
        }
    }
}

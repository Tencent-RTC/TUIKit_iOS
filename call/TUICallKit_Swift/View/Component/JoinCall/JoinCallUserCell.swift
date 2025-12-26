//
//  JoinCallUserCell.swift (Refactored Version)
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import Foundation
import UIKit

import AtomicXCore

class JoinCallUserCell: UICollectionViewCell {
    
    private var participant: CallParticipantInfo = CallParticipantInfo()
    
    private let userIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 4.0
        imageView.image = CallKitBundle.getBundleImage(name: "default_user_icon")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: UI Specification Processing
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if isViewReady { return }
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }
    
    private func constructViewHierarchy() {
        contentView.addSubview(userIcon)
    }
    
    private func activateConstraints() {
        NSLayoutConstraint.activate([
            userIcon.topAnchor.constraint(equalTo: contentView.topAnchor),
            userIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            userIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            userIcon.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    func setModel(participant: CallParticipantInfo) {
        self.participant = participant
        setUserIcon()
    }
    
    private func setUserIcon() {
        let userImage = CallKitBundle.getBundleImage(name: "default_user_icon")
       
        if let url = URL(string: participant.avatarURL), !participant.avatarURL.isEmpty {
            userIcon.sd_setImage(with: url, placeholderImage: userImage)
        } else {
            userIcon.image = userImage
        }
    }
}

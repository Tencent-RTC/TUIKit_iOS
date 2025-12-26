//
//  LinkMicBaseCell.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/5/30.
//

import UIKit
import Combine
import AtomicXCore
import AtomicX

class LinkMicBaseCell: UITableViewCell {
    var cancellableSet: Set<AnyCancellable> = []
    var seatInfo: SeatUserInfo? {
        didSet {
            guard let seatInfo = seatInfo else {
                return
            }
            avatarView.setContent(.url(seatInfo.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
            nameLabel.text = seatInfo.userName
        }
    }
    var seatApplication: LiveUserInfo? {
        didSet {
            guard let seatApplication = seatApplication else {
                return
            }
            avatarView.setContent(.url(seatApplication.avatarURL, placeholder: UIImage.avatarPlaceholderImage))
            nameLabel.text = seatApplication.userName
        }
    }
    
    lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("",placeholder: UIImage.avatarPlaceholderImage),
            size: .m,
            shape: .round
        )
        contentView.addSubview(avatar)
        return avatar
    }()
    
    lazy var nameLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Regular16)
        }
        return label
    }()
    
    let lineView: UIView = {
        let view = UIView()
        view.backgroundColor = .g3.withAlphaComponent(0.3)
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

//
//  RTCExperienceRoomButtonView.swift
//  mine
//

import UIKit
import AtomicX
import SnapKit

class RTCExperienceRoomButtonView: UIButton {
    
    var onClicked: (() -> Void)?
    
    private let leftImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        return imageView
    }()
    
    private let rightImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        return imageView
    }()
    
    private let label: UILabel = {
        let label = UILabel()
        label.font = ThemeStore.shared.typographyTokens.Medium14
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func constructViewHierarchy() {
        addSubview(leftImageView)
        addSubview(label)
        addSubview(rightImageView)
    }
    
    private func activateConstraints() {
        leftImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.left.equalToSuperview().offset(26)
            make.width.height.equalTo(18)
        }
        
        label.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.left.equalToSuperview().offset(62)
        }
        
        rightImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.width.height.equalTo(18)
        }
    }
    
    private func bindInteraction() {
        addTarget(self, action: #selector(buttonClicked), for: .touchUpInside)
    }
    
    func configure(with title: String, leftImageName: String, rightImageName: String) {
        label.text = title
        leftImageView.image = UIImage(named: leftImageName)
        rightImageView.image = UIImage(named: rightImageName)
    }
    
    @objc private func buttonClicked() {
        onClicked?()
    }
}

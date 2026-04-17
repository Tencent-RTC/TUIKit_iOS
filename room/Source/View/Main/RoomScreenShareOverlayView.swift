//
//  RoomScreenShareOverlayView.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/3/31.
//  Copyright © 2026 Tencent. All rights reserved.
//

public protocol RoomScreenShareOverlayViewDelegate: AnyObject {
    func onStopScreenShareButtonTapped()
}

public class RoomScreenShareOverlayView: UIView {
    // MARK: - Properties
    weak var delegate: RoomScreenShareOverlayViewDelegate?

    // MARK: - UI Components
    private let screenSharingImageView: UIImageView = {
        let imageView = UIImageView(image: ResourceLoader.loadImage("room_screen_sharing"))
        return imageView
    }()
    
    private let screenShareLabel: UILabel = {
        let label = UILabel()
        label.text = .screenSharing
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = .white
        return label
    }()
    
    private let stopScreenShareButton: UIButton = {
        let button = UIButton()
        button.setTitle(.stopScreenShare, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = RoomFonts.pingFangSCFont(size: 12, weight: .regular)
        button.backgroundColor = RoomColors.stopScreenShareBackground
        button.layer.cornerRadius = 6
        return button
    }()
    
    init() {
        super.init(frame: .zero)
        backgroundColor = RoomColors.g2
        setupViews()
        setupConstraints()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        addSubview(screenSharingImageView)
        addSubview(screenShareLabel)
        addSubview(stopScreenShareButton)
    }
    
    private func setupConstraints() {
        screenSharingImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(screenShareLabel.snp.top)
        }
        
        screenShareLabel.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
        }
        
        stopScreenShareButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(screenShareLabel.snp.bottom).offset(20)
            make.size.equalTo(CGSize(width: 102, height: 34))
        }
    }
    
    private func setupBindings() {
        stopScreenShareButton.addTarget(self, action: #selector(stopScreenShareButtonTapped), for: .touchUpInside)
    }
    
    @objc private func stopScreenShareButtonTapped() {
        delegate?.onStopScreenShareButtonTapped()
    }
}


fileprivate extension String {
    static let screenSharing = "roomkit_screen_capturing".localized
    static let stopScreenShare = "roomkit_stop_screen_share".localized
}

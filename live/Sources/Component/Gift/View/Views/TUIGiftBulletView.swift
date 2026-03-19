//
//  TUIGiftBulletView.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/1/2.
//

import UIKit
import AtomicX
import AtomicXCore
import SnapKit

typealias TUIGiftAnimationCompletionBlock = (Bool, String) -> Void

class TUIGiftBulletView: UIView {
    
    // MARK: - Properties
    private var giftData: TUIGiftData?
    private var currentGiftCount: UInt8 = 0
    private var comboKey: String = ""
    private var completionBlock: TUIGiftAnimationCompletionBlock?
    private var dismissTimer: Timer?
    private let stayDuration: TimeInterval = 5.0
    private var isAnimationPlaying = false

    // MARK: - UI Components
    private lazy var bgView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.layer.cornerRadius = 22
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .icon(image: UIImage()),
            size: .m,
            shape: .round
        )
        return avatar
    }()

    private let giftIconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    private lazy var nickNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        return label
    }()

    private lazy var giveDescLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        return label
    }()
    
    private lazy var digitLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.italicSystemFont(ofSize: 24)
        label.textColor = .white
        label.textAlignment = .left
        label.text = "x1"
        return label
    }()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        dismissTimer?.invalidate()
    }

    // MARK: - Public Methods
    
    func setGiftData(_ data: TUIGiftData) {
        self.giftData = data
        self.comboKey = data.comboKey
        self.currentGiftCount = data.giftCount
        
        let nickName = data.sender.userName.isEmpty ? data.sender.userID : data.sender.userName
        nickNameLabel.text = data.sender.isSelf ? .meText : nickName
        giveDescLabel.text = data.giftInfo.name
        
        giftIconView.kf.setImage(with: URL(string: data.giftInfo.iconURL))
        avatarView.setContent(.url(data.sender.avatarURL, placeholder: nil))
        
        updateDigitLabel()
    }
    
    func addGiftCount(_ count: UInt8) {
        currentGiftCount += count
        updateDigitLabel()
        
        performBounceAnimation()
        
        startDismissTimer()
    }

    func play(completion: @escaping TUIGiftAnimationCompletionBlock) {
        guard !isAnimationPlaying else { return }
        isAnimationPlaying = true
        self.completionBlock = completion
        
        self.transform = CGAffineTransform(translationX: -UIScreen.main.bounds.width, y: 0)
        self.alpha = 1
        
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.transform = .identity
        } completion: { _ in
            self.startDismissTimer()
        }
    }

    func stop() {
        dismissTimer?.invalidate()
        removeFromSuperview()
        completionBlock?(false, self.comboKey)
    }
    
    // MARK: - Private Methods
    
    private func startDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: stayDuration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }
    
    private func dismiss() {
        dismissTimer?.invalidate()
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -30)
        }) { [weak self] _ in
            guard let self = self else { return }
            self.completionBlock?(true, self.comboKey)
            self.removeFromSuperview()
        }
    }
    
    private func updateDigitLabel() {
        digitLabel.text = "x\(currentGiftCount)"
        if currentGiftCount > 99 { digitLabel.textColor = .red }
    }
    
    private func performBounceAnimation() {
        digitLabel.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.5, options: []) {
            self.digitLabel.transform = .identity
        }
    }
    
    private func setupUI() {
        addSubview(bgView)
        addSubview(digitLabel)
        
        bgView.addSubview(avatarView)
        bgView.addSubview(nickNameLabel)
        bgView.addSubview(giveDescLabel)
        bgView.addSubview(giftIconView)
        
        bgView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(44)
        }
        
        avatarView.snp.makeConstraints { make in
            make.leading.equalTo(bgView).offset(2)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        nickNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(8)
            make.top.equalTo(avatarView).offset(2)
            make.width.lessThanOrEqualTo(100)
        }
        
        giveDescLabel.snp.makeConstraints { make in
            make.leading.equalTo(nickNameLabel)
            make.bottom.equalTo(avatarView).offset(-2)
            make.width.lessThanOrEqualTo(100)
        }
        
        giftIconView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(nickNameLabel.snp.trailing).offset(8)
            make.leading.greaterThanOrEqualTo(giveDescLabel.snp.trailing).offset(8)
            
            make.trailing.equalToSuperview().offset(-10)
            
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
    
        
        digitLabel.snp.makeConstraints { make in
            make.leading.equalTo(bgView.snp.trailing).offset(5)
            make.centerY.equalToSuperview().offset(-2)
            make.trailing.lessThanOrEqualToSuperview()
        }
    }
}

//MARK: localized String
private extension String {
    static let meText = internalLocalized("common_gift_me")
}

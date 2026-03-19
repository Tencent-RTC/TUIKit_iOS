//
//  GiftBaseCell.swift
//  TUILiveKit
//
//  Created by CY zhao on 2026/2/5.
//

import UIKit
import SnapKit
import Kingfisher
import AtomicXCore

public struct GiftCellConfiguration {
    /// 连击倒计时 (仅 Combo 有效)
    public var comboDuration: TimeInterval = 5.0
    /// 批量步长 (仅 Batch 有效)
    public var batchStep: Int = 5
    
    public init() {}
}

public protocol GiftCellDelegate: AnyObject {
    func cell(_ cell: UICollectionViewCell, onSend gift: Gift, count: UInt)
}

public class GiftBaseCell: UICollectionViewCell {
    public weak var delegate: GiftCellDelegate?
    public var giftInfo: Gift? {
        didSet {
            guard let gift = giftInfo else { return }
            updateContent(gift: gift)
        }
    }
    
    var config = GiftCellConfiguration()
    var cellRadius: CGFloat = 10.0
    
    // MARK: - UI Components
    
    lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var selectedView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = cellRadius
        view.layer.masksToBounds = true
        view.layer.borderColor = UIColor.buttonPrimaryDefaultColor.cgColor
        view.layer.borderWidth = 0
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var imageBgView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        //view.backgroundColor = .bgOperateColor // 默认背景色
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var giftImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 12)
        label.textColor = .textPrimaryColor
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()
    
    lazy var priceLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 10)
        label.textColor = .textSecondaryColor
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }()
    
    lazy var sendButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(.sendOut, for: .normal)
        btn.setTitleColor(.textPrimaryColor, for: .normal)
        btn.titleLabel?.font = .customFont(ofSize: 12, weight: .medium)
        btn.backgroundColor = .buttonPrimaryDefaultColor
        btn.layer.masksToBounds = true
        btn.layer.cornerRadius = cellRadius
        btn.addTarget(self, action: #selector(didTapSendButton), for: .touchUpInside)
        btn.isHidden = true
        return btn
    }()
    
    // MARK: - Init & Layout
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.clipsToBounds = false
        self.contentView.clipsToBounds = false
        setupBaseUI()
        setupTapGesture()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupBaseUI() {
        contentView.addSubview(containerView)
        
        containerView.addSubview(selectedView)
        containerView.addSubview(imageBgView)
        imageBgView.addSubview(giftImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(priceLabel)
        containerView.addSubview(sendButton)
        
        // --- 布局约束 ---
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(74)
            make.top.greaterThanOrEqualToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
                
        imageBgView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(2)
            make.leading.equalToSuperview().offset(2)
            make.trailing.equalToSuperview().offset(-2)
            make.height.equalTo(imageBgView.snp.width)
        }
        
        giftImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(imageBgView.snp.bottom).offset(2)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(20)
        }
        
        sendButton.snp.makeConstraints { make in
            make.edges.equalTo(nameLabel)
        }
        
        selectedView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(nameLabel.snp.bottom).offset(2)
        }
    
        priceLabel.snp.makeConstraints { make in
            make.top.equalTo(selectedView.snp.bottom).offset(0)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(14)
            make.bottom.equalToSuperview()
        }
    }
    
    // MARK: - Logic
    
    open var isActionStyle: Bool { return true }
    
    public func configure(with config: GiftCellConfiguration) {
        self.config = config
    }
    
    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        contentView.addGestureRecognizer(tap)
    }
    
    @objc private func handleTap() {
        if isSelected {
            handleHitWhenSelected()
        }
    }
    
    open func handleHitWhenSelected() { }
    
    @objc func didTapSendButton() {
        performSendAction()
    }
    
    open func performSendAction() {
        guard let gift = giftInfo else { return }
        delegate?.cell(self, onSend: gift, count: 1)
    }
    
    open func updateContent(gift: Gift) {
        giftImageView.kf.setImage(with: URL(string: gift.iconURL))
        nameLabel.text = gift.name
        priceLabel.text = "\(gift.coins)"
    }
    
    // MARK: - State Update
    
    public override var isSelected: Bool {
        didSet {
            updateSelectionState()
        }
    }
    
    open func updateSelectionState() {
        let showAction = isActionStyle && isSelected
        
        selectedView.layer.borderWidth = isSelected ? 2 : 0
        selectedView.backgroundColor = isSelected ? .buttonPrimaryDefaultColor : .clear
        
        imageBgView.backgroundColor = isSelected ? .bgEntrycardColor : .clear
        
        //nameLabel.isHidden = showAction
        sendButton.isHidden = !showAction
        
        // 强制布局更新
        selectedView.isHidden = false
        imageBgView.isHidden = false
        //priceLabel.isHidden = false
    }
}

extension GiftBaseCell: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let view = touch.view, view.isKind(of: UIButton.self) {
            return false
        }
        return true
    }
}

private extension String {
    static var sendOut = internalLocalized("common_gift_give_gift")
}

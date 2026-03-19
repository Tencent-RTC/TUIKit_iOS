//
//  GiftComboCell.swift
//  TUILiveKit
//
//  Created by CY zhao on 2026/2/5.
//

import UIKit
import SnapKit
import AtomicXCore
import AtomicX

public class GiftComboCell: GiftBaseCell {
    
    // 开启操作模式
    override open var isActionStyle: Bool { return true }
    
    // MARK: - Config & Constants
    var primaryColor: UIColor {
        return ThemeStore.shared.colorTokens.buttonColorPrimaryActive
    }
    private let kProgressLineWidth: CGFloat = 3.0
    
    // MARK: - State Management
    private var currentComboCount = 0
    private var comboTimer: Timer?

    private var isComboActive: Bool = false
    
    // MARK: - UI Components
    
    private lazy var comboContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
    private lazy var haloBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = primaryColor.withAlphaComponent(0.15)
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var progressLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = primaryColor.cgColor
        layer.lineWidth = kProgressLineWidth
        layer.lineCap = .round
        layer.strokeEnd = 1.0
        layer.transform = CATransform3DMakeRotation(-.pi / 2, 0, 0, 1)
        return layer
    }()
    
    private lazy var innerButton: UIView = {
        let view = UIView()
        view.backgroundColor = primaryColor
        view.layer.shadowColor = primaryColor.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowOpacity = 0.3
        view.layer.shadowRadius = 3
        return view
    }()
    
    private lazy var actionLabel: UILabel = {
        let label = UILabel()
        label.text = "连击"
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private lazy var badgeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = primaryColor
        view.layer.cornerRadius = 3
        view.layer.masksToBounds = true
        view.isHidden = true
        return view
    }()
    
    private lazy var comboCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .heavy)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Init & Layout
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupComboUI()
        setupInteraction()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupComboUI() {
        contentView.addSubview(comboContainerView)
        comboContainerView.addSubview(haloBackgroundView)
        comboContainerView.layer.addSublayer(progressLayer)
        comboContainerView.addSubview(innerButton)
        innerButton.addSubview(actionLabel)
        
        contentView.addSubview(badgeContainer)
        badgeContainer.addSubview(comboCountLabel)
                
        comboContainerView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(imageBgView).offset(2)
            make.width.height.equalTo(imageBgView).multipliedBy(0.9)
        }
        
        haloBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        innerButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(comboContainerView).multipliedBy(0.75)
        }
        
        actionLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        badgeContainer.snp.makeConstraints { make in
            make.bottom.equalTo(comboContainerView.snp.top).offset(2)
            make.centerX.equalToSuperview()
            make.height.equalTo(16)
            make.width.greaterThanOrEqualTo(34)
        }
        
        comboCountLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(6)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        comboContainerView.layoutIfNeeded()
        let bounds = comboContainerView.bounds
        
        haloBackgroundView.layer.cornerRadius = bounds.width / 2
        
        innerButton.layoutIfNeeded()
        innerButton.layer.cornerRadius = innerButton.bounds.width / 2
  
        let radius = (bounds.width - kProgressLineWidth) / 2
        let path = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                                radius: radius,
                                startAngle: 0,
                                endAngle: -.pi * 2,
                                clockwise: false).cgPath
        
        progressLayer.frame = bounds
        progressLayer.path = path
    }
    
    // MARK: - Logic Implementation
    
    public override var isSelected: Bool {
        didSet {
            super.isSelected = isSelected
            
            if !isSelected {
                resetComboState()
            }
        }
    }
    
    public override func updateSelectionState() {
        super.updateSelectionState()

        if isComboActive {
            selectedView.isHidden = true
            sendButton.isHidden = true
            //imageBgView.backgroundColor = .clear
            imageBgView.isHidden = true
        }
        comboContainerView.isHidden = !isComboActive
        badgeContainer.isHidden = !isComboActive
    }
    
    public override func performSendAction() {
        triggerCombo()
    }
    
    public override func handleHitWhenSelected() {
        triggerCombo()
        
        if isComboActive {
            animateInnerButtonScale(to: 0.9)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.animateInnerButtonScale(to: 1.0)
            }
        }
    }
    
    // MARK: - Interaction (Button Gesture)
    
    private func setupInteraction() {
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handleInnerPress(_:)))
        press.minimumPressDuration = 0
        press.cancelsTouchesInView = false
        innerButton.addGestureRecognizer(press)
    }
    
    @objc private func handleInnerPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            animateInnerButtonScale(to: 0.9)
        case .ended:
            triggerCombo()
            animateInnerButtonScale(to: 1.0)
        case .cancelled, .failed:
            animateInnerButtonScale(to: 1.0)
        default: break
        }
    }
    
    private func animateInnerButtonScale(to scale: CGFloat) {
        UIView.animate(withDuration: 0.1) {
            self.innerButton.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
    
    // MARK: - Core Combo Logic
    
    private func triggerCombo() {
        guard isSelected else { return }
        
        if !isComboActive {
            isComboActive = true
            updateSelectionState()
        }
        
        currentComboCount += 1
        
        comboCountLabel.text = "x\(currentComboCount)"
        
        badgeContainer.layer.removeAllAnimations()
        
        if currentComboCount == 1 {
            badgeContainer.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        } else {
            badgeContainer.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }
        
        UIView.animate(withDuration: 0.5,
                       delay: 0,
                       usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 1.0,
                       options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]) {
            self.badgeContainer.transform = .identity
        }
        delegate?.cell(self, onSend: giftInfo!, count: 1)
        
        startComboCountdown()
    }
    
    private func startComboCountdown() {
        comboTimer?.invalidate()
        progressLayer.removeAllAnimations()
        
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 1.0
        animation.toValue = 0.0
        animation.duration = config.comboDuration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        progressLayer.add(animation, forKey: "comboCountdown")
        
        comboTimer = Timer.scheduledTimer(withTimeInterval: config.comboDuration, repeats: false) { [weak self] _ in
            self?.resetComboState()
        }
    }
    
    private func resetComboState() {
        comboTimer?.invalidate()
        comboTimer = nil
        currentComboCount = 0
        progressLayer.removeAllAnimations()
        
        isComboActive = false
        
        updateSelectionState()
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        comboTimer?.invalidate()
        comboTimer = nil
        isComboActive = false
        currentComboCount = 0
        progressLayer.removeAllAnimations()
        
        comboContainerView.isHidden = true
        badgeContainer.isHidden = true
    }
}

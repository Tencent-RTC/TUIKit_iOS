//
//  GiftBatchCell.swift
//  TUILiveKit
//
//  Created by CY zhao on 2026/2/5.
//

import UIKit
import SnapKit
import AtomicXCore

public class GiftBatchCell: GiftBaseCell {
    
    override open var isActionStyle: Bool { return true }
    
    // MARK: - State
    private var selectedCount: UInt = 0
    private var longPressTimer: Timer?
    
    // MARK: - UI
    private lazy var badgeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        label.textAlignment = .right
        
        let attrString = NSAttributedString(
            string: "x0",
            attributes: [
                .strokeColor: UIColor.black.withAlphaComponent(0.5),
                .foregroundColor: UIColor.white,
                .strokeWidth: -3.0
            ]
        )
        label.attributedText = attrString
        label.isHidden = true
        return label
    }()
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBatchUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupBatchUI() {
        contentView.addSubview(badgeLabel)
        
        badgeLabel.snp.makeConstraints { make in
            make.top.equalTo(imageBgView).offset(2)
            make.trailing.equalTo(imageBgView).offset(-4)
        }
    }
    
    private func setupGestures() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        contentView.addGestureRecognizer(longPress)
    }
    
    // MARK: - Logic Implementation
    
    public override var isSelected: Bool {
        didSet {
            super.isSelected = isSelected
            badgeLabel.isHidden = !isSelected
            
            if isSelected {
                if selectedCount == 0 {
                    selectedCount = 1
                }
                updateBadgeUI(animate: true)
            } else {
                selectedCount = 0
                stopLongPressTimer()
            }
        }
    }
    
    public override func handleHitWhenSelected() {
        increaseCount()
        performScaleAnimation()
    }
    
    // 核心算法：策略 B (智能阶梯)
    private func getStep(for current: UInt) -> UInt {
        if current < 10 {
            return 1       // 1-9: 个位递增
        } else if current < 100 {
            return 5      // 10-99: 十位递增
        } else {
            return 50     // 100+: 百位递增
        }
    }
    
    @discardableResult
    private func increaseCount() -> Bool {
        let step = getStep(for: selectedCount)
        let newCount = selectedCount + step
        
        if newCount > 999 {
            selectedCount = 1
        } else {
            selectedCount = newCount
        }
        
        updateBadgeUI(animate: true)
        return true
    }
    
    // MARK: - Long Press
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard isSelected else { return }

            switch gesture.state {
            case .began:
                startLongPressTimer()
            case .ended, .cancelled, .failed:
                stopLongPressTimer()
            default:
                break
            }
        }
    
    private func startLongPressTimer() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            self.increaseCount()
            generator.impactOccurred()
        }
    }
    
    private func stopLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        performScaleAnimation(scale: 1.3)
    }
    
    // MARK: - UI Updates
    
    private func updateBadgeUI(animate: Bool) {
        let attrString = NSAttributedString(
            string: "x\(selectedCount)",
            attributes: [
                .strokeColor: UIColor.black.withAlphaComponent(0.5),
                .foregroundColor: UIColor.white,
                .strokeWidth: -3.0,
            ]
        )
        badgeLabel.attributedText = attrString
        
        if animate {
            let isLongPressing = (longPressTimer != nil)
            performScaleAnimation(scale: isLongPressing ? 1.1 : 1.2)
        }
    }
    
    private func performScaleAnimation(scale: CGFloat = 1.2) {
        badgeLabel.transform = CGAffineTransform(scaleX: scale, y: scale)
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: []) {
            self.badgeLabel.transform = .identity
        }
    }
    
    // MARK: - Send Action
    
    public override func performSendAction() {
        guard let gift = giftInfo, selectedCount > 0 else { return }
        
        delegate?.cell(self, onSend: gift, count: selectedCount)
        
        selectedCount = 1
        updateBadgeUI(animate: true)
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        stopLongPressTimer()
        selectedCount = 0
    }
}

//
//  AISubtitleLineView.swift
//  AISubtitle
//

import UIKit
import SnapKit

/// Single subtitle line view with streaming text animation and fade effects.
/// When text exceeds maxLines, the oldest (top) content is clipped and the newest (bottom) content remains visible.
public class AISubtitleLineView: UIView {
    
    // MARK: - Properties
    
    private let textLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.textAlignment = .left
        return label
    }()
    
    /// Container that clips overflow from the top, showing only the latest lines.
    private let clipContainer: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()
    
    private var fullText: String = ""
    private var currentCharIndex: Int = 0
    private var streamTimer: Timer?
    private var style: TextStyle = TextStyle()
    private var streamAnimationDuration: TimeInterval = 0.03
    
    private var maxLines: Int = 0
    private var clipHeightConstraint: Constraint?
    
    public var onTextUpdateCompleted: (() -> Void)?
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    deinit {
        streamTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(clipContainer)
        clipContainer.addSubview(textLabel)
        
        clipContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Label pins to left, right, bottom of container.
        // Top has low priority: when text fits, top aligns with container top (no gap);
        // when text overflows maxHeight, the low-priority top breaks and label extends
        // above container, clipped by clipsToBounds.
        textLabel.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalToSuperview().priority(.low)
            make.width.equalToSuperview()
        }
    }
    
    // MARK: - Configuration
    
    /// Update the maximum number of lines for the text label.
    /// When maxLines > 0, the container height is capped to show only that many lines.
    public func updateMaxLines(_ maxLines: Int) {
        self.maxLines = maxLines
        updateClipHeight()
    }
    
    public func configure(style: TextStyle, animationDuration: TimeInterval = 0.03) {
        self.style = style
        self.streamAnimationDuration = animationDuration
        
        textLabel.textColor = style.textColor
        textLabel.font = style.font
        
        textLabel.layer.shadowColor = style.shadowColor.cgColor
        textLabel.layer.shadowOffset = style.shadowOffset
        textLabel.layer.shadowRadius = style.shadowRadius
        textLabel.layer.shadowOpacity = 1.0
        
        updateClipHeight()
    }
    
    /// Calculate and update the clip container max height based on maxLines and font.
    private func updateClipHeight() {
        clipHeightConstraint?.deactivate()
        clipHeightConstraint = nil
        
        guard maxLines > 0, let font = textLabel.font else { return }
        let lineHeight = font.lineHeight
        let maxHeight = ceil(lineHeight * CGFloat(maxLines))
        
        clipContainer.snp.makeConstraints { make in
            clipHeightConstraint = make.height.lessThanOrEqualTo(maxHeight).constraint
        }
        clipHeightConstraint?.activate()
    }
    
    // MARK: - Text Update
    
    /// Update the full text, optionally with streaming animation.
    public func updateText(_ text: String, animated: Bool = true) {
        streamTimer?.invalidate()
        streamTimer = nil
        
        let previousText = fullText
        fullText = text
        
        if animated && !text.isEmpty {
            if text.hasPrefix(previousText) && text.count > previousText.count {
                currentCharIndex = previousText.count
                startStreamAnimation()
            } else {
                currentCharIndex = 0
                textLabel.text = ""
                startStreamAnimation()
            }
        } else {
            textLabel.text = text
            onTextUpdateCompleted?()
        }
    }
    
    /// Append text with a cross-dissolve transition (no per-character animation).
    public func appendText(_ text: String, animated: Bool = true) {
        streamTimer?.invalidate()
        streamTimer = nil
        
        fullText += text
        currentCharIndex = fullText.count
        
        if animated {
            UIView.transition(with: textLabel, duration: 0.05, options: .transitionCrossDissolve) {
                self.textLabel.text = self.fullText
            }
        } else {
            textLabel.text = fullText
        }
    }
    
    public func clearText() {
        streamTimer?.invalidate()
        streamTimer = nil
        fullText = ""
        currentCharIndex = 0
        textLabel.text = ""
    }
    
    public var currentText: String {
        return fullText
    }
    
    // MARK: - Stream Animation
    
    private func startStreamAnimation() {
        streamTimer = Timer.scheduledTimer(withTimeInterval: streamAnimationDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.currentCharIndex < self.fullText.count {
                self.currentCharIndex += 1
                let index = self.fullText.index(self.fullText.startIndex, offsetBy: self.currentCharIndex)
                let displayText = String(self.fullText[..<index])
                
                UIView.transition(with: self.textLabel, duration: 0.05, options: .transitionCrossDissolve) {
                    self.textLabel.text = displayText
                }
            } else {
                timer.invalidate()
                self.streamTimer = nil
                self.onTextUpdateCompleted?()
            }
        }
    }
    
    // MARK: - Fade Animation
    
    public func fadeIn(duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        alpha = 0
        isHidden = false
        
        UIView.animate(withDuration: duration, animations: {
            self.alpha = 1
        }, completion: { _ in
            completion?()
        })
    }
    
    public func fadeOut(duration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: duration, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.isHidden = true
            completion?()
        })
    }
}

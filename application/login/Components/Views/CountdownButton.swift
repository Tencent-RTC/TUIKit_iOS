//
//  CountdownButton.swift
//  login
//

import UIKit
import AtomicX

class CountdownButton: UIButton {
    
    private var countdownTimer: Timer?
    private(set) var countdown: Int = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStyle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupStyle() {
        setTitle(LoginLocalize("V2.Live.LinkMicNew.getverificationcode"), for: .normal)
        setTitle(LoginLocalize("V2.Live.LinkMicNew.getverificationcode"), for: .disabled)
        titleLabel?.font = ThemeStore.shared.typographyTokens.Medium16
        setTitleColor(ThemeStore.shared.colorTokens.buttonColorPrimaryDefault, for: .normal)
        setTitleColor(ThemeStore.shared.colorTokens.textColorDisable, for: .disabled)
        adjustsImageWhenHighlighted = false
        isEnabled = false
    }
    
    // MARK: - Public
    
    func startCountdown(duration: Int = 60) {
        stopCountdown()
        countdown = duration
        isUserInteractionEnabled = false
        updateTitle()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.countdown -= 1
            if self.countdown <= 0 {
                self.stopCountdown()
            } else {
                self.updateTitle()
            }
        }
    }
    
    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdown = 0
        isUserInteractionEnabled = true
        resetTitle()
    }
    
    func updateCountdown(_ value: Int) {
        countdown = value
        if value > 0 {
            isUserInteractionEnabled = false
            updateTitle()
        } else {
            stopCountdown()
        }
    }
    
    // MARK: - Private
    
    private func updateTitle() {
        setTitle("\(countdown)s", for: .normal)
        setTitle("\(countdown)s", for: .disabled)
        sizeToFit()
    }
    
    private func resetTitle() {
        setTitle(LoginLocalize("V2.Live.LinkMicNew.getverificationcode"), for: .normal)
        setTitle(LoginLocalize("V2.Live.LinkMicNew.getverificationcode"), for: .disabled)
        sizeToFit()
    }
    
    deinit {
        countdownTimer?.invalidate()
    }
}

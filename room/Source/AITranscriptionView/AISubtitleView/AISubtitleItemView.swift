//
//  AISubtitleItemView.swift
//  AISubtitle
//

import UIKit
import SnapKit
import Kingfisher

/// Single-speaker subtitle item view with avatar, speaker label, and dual-line subtitles.
public class AISubtitleItemView: UIView {
    
    // MARK: - UI Elements
    
    private let horizontalStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .top
        stack.distribution = .fill
        return stack
    }()
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        return stack
    }()
    
    private let speakerLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        return label
    }()
    
    private let sourceLineView = AISubtitleLineView()
    private let translationLineView = AISubtitleLineView()
    
    private var config: AISubtitleConfig = .default
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(horizontalStack)
        
        horizontalStack.addArrangedSubview(avatarImageView)
        horizontalStack.addArrangedSubview(contentStackView)
        
        contentStackView.addArrangedSubview(speakerLabel)
        contentStackView.addArrangedSubview(sourceLineView)
        contentStackView.addArrangedSubview(translationLineView)
        
        horizontalStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let avatarSize = config.avatarStyle.size
        avatarImageView.snp.makeConstraints { make in
            make.width.equalTo(avatarSize)
            make.height.equalTo(avatarSize)
        }
        avatarImageView.layer.cornerRadius = avatarSize / 2
        
        sourceLineView.setContentHuggingPriority(.required, for: .vertical)
        sourceLineView.setContentCompressionResistancePriority(.required, for: .vertical)
        translationLineView.setContentHuggingPriority(.required, for: .vertical)
        translationLineView.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    // MARK: - Configuration
    
    func applyConfig(_ config: AISubtitleConfig) {
        self.config = config
        
        horizontalStack.layoutMargins = config.contentInsets
        horizontalStack.isLayoutMarginsRelativeArrangement = true
        
        avatarImageView.isHidden = !config.showAvatar
        horizontalStack.spacing = config.avatarStyle.spacing
        let avatarSize = config.avatarStyle.size
        avatarImageView.snp.updateConstraints { make in
            make.width.equalTo(avatarSize)
            make.height.equalTo(avatarSize)
        }
        avatarImageView.layer.cornerRadius = avatarSize / 2
        
        contentStackView.spacing = config.lineSpacing
        
        speakerLabel.textColor = config.speakerStyle.nameColor
        speakerLabel.font = config.speakerStyle.nameFont
        contentStackView.setCustomSpacing(config.speakerStyle.bottomSpacing, after: speakerLabel)
        
        sourceLineView.configure(style: config.sourceStyle, animationDuration: config.streamAnimationDuration)
        translationLineView.configure(style: config.translationStyle, animationDuration: config.streamAnimationDuration)
        
        updateDisplayMode(config)
    }
    
    func bindData(_ data: AITranscriptionData, config: AISubtitleConfig) {
        applyConfig(config)
        
        if config.showSpeaker && !data.speakerUserName.isEmpty {
            speakerLabel.text = data.speakerUserName
            speakerLabel.isHidden = false
        } else {
            speakerLabel.isHidden = true
        }
        
        updateAvatar("", config: config)
        
        if config.displayMode != .translationOnly {
            sourceLineView.updateText(data.sourceText, animated: false)
        }
        if config.displayMode != .sourceOnly {
            translationLineView.updateText(data.translationText, animated: false)
        }
    }
    
    // MARK: - Streaming Text Updates
    
    /// Update the maximum number of lines for source and translation text.
    func updateMaxLines(_ maxLines: Int) {
        sourceLineView.updateMaxLines(maxLines)
        translationLineView.updateMaxLines(maxLines)
    }
    
    func appendSourceText(_ text: String, animated: Bool = true) {
        sourceLineView.appendText(text, animated: animated)
    }
    
    func appendTranslationText(_ text: String, animated: Bool = true) {
        translationLineView.appendText(text, animated: animated)
    }
    
    func updateSourceText(_ text: String, animated: Bool = true) {
        sourceLineView.updateText(text, animated: animated)
    }
    
    func updateTranslationText(_ text: String, animated: Bool = true) {
        translationLineView.updateText(text, animated: animated)
    }
    
    // MARK: - Private
    
    private func updateDisplayMode(_ config: AISubtitleConfig) {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if config.showSpeaker {
            contentStackView.addArrangedSubview(speakerLabel)
            contentStackView.setCustomSpacing(config.speakerStyle.bottomSpacing, after: speakerLabel)
        }
        
        switch config.displayMode {
        case .sourceOnly:
            contentStackView.addArrangedSubview(sourceLineView)
            sourceLineView.isHidden = false
            translationLineView.isHidden = true
        case .translationOnly:
            contentStackView.addArrangedSubview(translationLineView)
            sourceLineView.isHidden = true
            translationLineView.isHidden = false
        case .dual:
            contentStackView.addArrangedSubview(sourceLineView)
            contentStackView.addArrangedSubview(translationLineView)
            sourceLineView.isHidden = false
            translationLineView.isHidden = false
        case .dualReversed:
            contentStackView.addArrangedSubview(translationLineView)
            contentStackView.addArrangedSubview(sourceLineView)
            sourceLineView.isHidden = false
            translationLineView.isHidden = false
        }
    }
    
    private func updateAvatar(_ urlString: String, config: AISubtitleConfig) {
        guard config.showAvatar else {
            avatarImageView.isHidden = true
            return
        }
        if let url = URL(string: urlString) {
            avatarImageView.kf.setImage(with: url, placeholder: config.avatarStyle.placeholder)
            avatarImageView.isHidden = false
        } else if let placeholder = config.avatarStyle.placeholder {
            avatarImageView.image = placeholder
            avatarImageView.isHidden = false
        } else {
            avatarImageView.isHidden = urlString.isEmpty
        }
    }
}

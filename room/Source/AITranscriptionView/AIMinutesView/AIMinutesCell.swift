//
//  AIMinutesCell.swift
//  AIMinutesView
//

import UIKit
import SnapKit

/// Table view cell for a single minutes entry.
public class AIMinutesCell: UITableViewCell {
    
    static let reuseIdentifier = "AIMinutesCell"
    
    // MARK: - UI Elements
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()
    
    private let speakerContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 8
        return stack
    }()
    
    private let speakerSpacer: UIView = {
        let view = UIView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }()
    
    private let cardView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()
    
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 6
        return stack
    }()
    
    private let sourceLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private let translationLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private var config: AIMinutesConfig = .default
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(speakerContainer)
        speakerContainer.addArrangedSubview(nameLabel)
        speakerContainer.addArrangedSubview(timestampLabel)
        speakerContainer.addArrangedSubview(speakerSpacer)
        
        contentView.addSubview(cardView)
        cardView.addSubview(contentStackView)
        contentStackView.addArrangedSubview(sourceLabel)
        contentStackView.addArrangedSubview(translationLabel)
    }
    
    // MARK: - Public Methods
    
    /// Full bind: applies style + layout + data. Used for initial cell configuration.
    /// - Parameters:
    ///   - data: The transcription data to display.
    ///   - config: The minutes view configuration.
    ///   - showSpeakerInfo: Whether to show speaker name and timestamp. Set to `false` when
    ///     the previous cell belongs to the same speaker within a 60-second window.
    public func bindData(_ data: AITranscriptionData, config: AIMinutesConfig, showSpeakerInfo: Bool = true) {
        self.config = config
        
        if showSpeakerInfo && config.showSpeaker && !data.speakerUserName.isEmpty {
            nameLabel.text = data.speakerUserName
            speakerContainer.isHidden = false
        } else {
            speakerContainer.isHidden = true
        }
        
        if showSpeakerInfo && config.showTimestamp && data.timestamp > 0 {
            timestampLabel.text = config.formatTimestamp(data.timestamp)
            timestampLabel.isHidden = false
        } else {
            timestampLabel.isHidden = true
        }
        
        applyStyle(config)
        updateTextLabels(data, config: config)
    }
    
    /// Incremental text update without re-applying style/constraints to avoid flicker.
    public func updateTexts(_ data: AITranscriptionData, config: AIMinutesConfig) {
        updateTextLabels(data, config: config)
    }
    
    // MARK: - Private
    
    private func updateTextLabels(_ data: AITranscriptionData, config: AIMinutesConfig) {
        switch config.displayMode {
        case .sourceOnly:
            if sourceLabel.text != data.sourceText {
                sourceLabel.text = data.sourceText
            }
            sourceLabel.isHidden = data.sourceText.isEmpty
            translationLabel.isHidden = true
        case .translationOnly:
            sourceLabel.isHidden = true
            if translationLabel.text != data.translationText {
                translationLabel.text = data.translationText
            }
            translationLabel.isHidden = data.translationText.isEmpty
        case .dual, .dualReversed:
            if sourceLabel.text != data.sourceText {
                sourceLabel.text = data.sourceText
            }
            sourceLabel.isHidden = data.sourceText.isEmpty
            if translationLabel.text != data.translationText {
                translationLabel.text = data.translationText
            }
            translationLabel.isHidden = data.translationText.isEmpty
        }
    }
    
    private func applyStyle(_ config: AIMinutesConfig) {
        let listInsets = config.listContentInsets
        let insets = config.itemContentInsets
        
        nameLabel.textColor = config.speakerStyle.nameColor
        nameLabel.font = config.speakerStyle.nameFont
        timestampLabel.textColor = config.speakerStyle.timestampColor
        timestampLabel.font = config.speakerStyle.timestampFont
        speakerContainer.spacing = config.speakerStyle.nameTimestampSpacing
        
        let showSpeaker = !speakerContainer.isHidden
        
        speakerContainer.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(listInsets.left + insets.left)
            make.trailing.equalToSuperview().offset(-(listInsets.right + insets.right))
            if !showSpeaker {
                make.height.equalTo(0)
            }
        }
        
        cardView.backgroundColor = config.itemBackgroundColor
        cardView.layer.cornerRadius = config.itemCornerRadius
        
        cardView.snp.remakeConstraints { make in
            make.top.equalTo(speakerContainer.snp.bottom).offset(showSpeaker ? config.speakerStyle.bottomSpacing : 0)
            make.leading.equalToSuperview().offset(listInsets.left + insets.left)
            make.trailing.equalToSuperview().offset(-(listInsets.right + insets.right))
            make.bottom.equalToSuperview()
        }
        
        contentStackView.spacing = config.lineSpacing
        contentStackView.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(insets.top)
            make.leading.equalToSuperview().offset(insets.left)
            make.trailing.equalToSuperview().offset(-insets.right)
            make.bottom.equalToSuperview().offset(-insets.bottom)
        }
        
        sourceLabel.textColor = config.sourceStyle.textColor
        sourceLabel.font = config.sourceStyle.font
        translationLabel.textColor = config.translationStyle.textColor
        translationLabel.font = config.translationStyle.font
    }
}

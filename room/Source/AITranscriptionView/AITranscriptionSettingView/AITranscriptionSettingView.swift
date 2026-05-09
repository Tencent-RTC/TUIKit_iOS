//
//  AITranscriptionSettingView.swift
//  AITranscriptionView
//
//  Created by adamsfliu on 2026/3/12.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import Combine
import SnapKit
import AtomicXCore

/// Setting row type.
public enum AITranscriptionSettingRowType {
    case `default`
    case alertSheet
    case toggle
}

/// Setting row data model.
public class AITranscriptionSettingRowData {
    public let title: String
    public var detail: String
    public let type: AITranscriptionSettingRowType
    public var isShowTips: Bool
    public var isOn: Bool
    
    public var onTap: (() -> Void)?
    public var onToggle: ((Bool) -> Void)?
    public var onTipsTap: ((UIView) -> Void)?
    
    public init(title: String,
                detail: String = "",
                type: AITranscriptionSettingRowType,
                isShowTips: Bool = false,
                isOn: Bool = false,
                onTap: (() -> Void)? = nil,
                onToggle: ((Bool) -> Void)? = nil,
                onTipsTap: ((UIView) -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.type = type
        self.isShowTips = isShowTips
        self.isOn = isOn
        self.onTap = onTap
        self.onToggle = onToggle
        self.onTipsTap = onTipsTap
    }
}

// MARK: - Delegate

public protocol AITranscriptionSettingViewDelegate: AnyObject {
    func settingViewDidTapBack(_ settingView: AITranscriptionSettingView)
}

// MARK: - AITranscriptionSettingCell

private class AITranscriptionSettingCell: UITableViewCell {
    
    static let reuseIdentifier = "AITranscriptionSettingCell"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .regular)
        label.textColor = .black
        return label
    }()
    
    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = RoomFonts.pingFangSCFont(size: 15, weight: .regular)
        label.textColor = RoomColors.aiRecordBorderColor
        return label
    }()
    
    private let arrowImageView: UIImageView = {
        let imageView = UIImageView(image: ResourceLoader.loadImage("room_ai_subtitle_right_arrow")?.withTintColor(RoomColors.g3))
        return imageView
    }()
    
    private let tipsImageView: UIImageView = {
        let imageView = UIImageView(image: ResourceLoader.loadImage("room_setting_info_tips"))
        return imageView
    }()
    
    private let toggleSwitch: UISwitch = {
        let sw = UISwitch()
        sw.onTintColor = RoomColors.tintBlue
        return sw
    }()
    
    private let separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = RoomColors.separator
        return view
    }()
    
    private var onToggle: ((Bool) -> Void)?
    private var onTipsTap: ((UIView) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = RoomColors.cardBackground
        contentView.backgroundColor = RoomColors.cardBackground
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(tipsImageView)
        contentView.addSubview(detailLabel)
        contentView.addSubview(arrowImageView)
        contentView.addSubview(toggleSwitch)
        contentView.addSubview(separatorLine)
        
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        
        tipsImageView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(2)
            make.centerY.equalToSuperview()
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(8)
            make.height.equalTo(14)
        }
        
        detailLabel.snp.makeConstraints { make in
            make.trailing.equalTo(arrowImageView.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
        }
        
        toggleSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        
        separatorLine.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    func bindData(_ data: AITranscriptionSettingRowData, isLastRow: Bool) {
        titleLabel.text = data.title
        onToggle = data.onToggle
        onTipsTap = data.onTipsTap
        separatorLine.isHidden = isLastRow
        tipsImageView.isHidden = !data.isShowTips
        tipsImageView.isUserInteractionEnabled = data.isShowTips
        
        if data.isShowTips {
            tipsImageView.gestureRecognizers?.forEach { tipsImageView.removeGestureRecognizer($0) }
            let tap = UITapGestureRecognizer(target: self, action: #selector(tipsTapEvent))
            tipsImageView.addGestureRecognizer(tap)
        }
        
        switch data.type {
        case .default:
            detailLabel.text = data.detail
            detailLabel.isHidden = false
            detailLabel.textColor = RoomColors.g5
            arrowImageView.isHidden = true
            toggleSwitch.isHidden = true
            
            detailLabel.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-16)
                make.centerY.equalToSuperview()
            }
        case .alertSheet:
            detailLabel.text = data.detail
            detailLabel.isHidden = false
            detailLabel.textColor = RoomColors.aiRecordBorderColor
            arrowImageView.isHidden = false
            toggleSwitch.isHidden = true
            
            detailLabel.snp.remakeConstraints { make in
                make.trailing.equalTo(arrowImageView.snp.leading).offset(-4)
                make.centerY.equalToSuperview()
            }
        case .toggle:
            detailLabel.isHidden = true
            arrowImageView.isHidden = true
            toggleSwitch.isHidden = false
            toggleSwitch.isOn = data.isOn
        }
    }
    
    @objc private func toggleChanged() {
        onToggle?(toggleSwitch.isOn)
    }
    
    @objc private func tipsTapEvent() {
        onTipsTap?(tipsImageView)
    }
}

// MARK: - AITranscriptionSettingView

/// AI subtitle settings view with source language, translation language, and bilingual toggle.
public class AITranscriptionSettingView: UIView {
    
    // MARK: - Properties
    
    public weak var delegate: AITranscriptionSettingViewDelegate?
    private weak var repository: AITranscriberRepository?
    private var rows: [AITranscriptionSettingRowData] = []
    private var cancellables = Set<AnyCancellable>()
    private var tooltipView: UIView?
    
    // MARK: - UI Elements
    
    private lazy var backButtonContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(ResourceLoader.loadImage("back_arrow"), for: .normal)
        button.isUserInteractionEnabled = false
        return button
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = .settingTitle
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g2
        return label
    }()
    
    private let sectionTitleLabel: UILabel = {
        let label = UILabel()
        label.text = .sectionTitle
        label.font = RoomFonts.pingFangSCFont(size: 13, weight: .regular)
        label.textColor = RoomColors.secondaryLabel
        return label
    }()
    
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .none
        tv.isScrollEnabled = false
        tv.backgroundColor = RoomColors.cardBackground
        tv.layer.cornerRadius = RoomCornerRadius.standard
        tv.layer.masksToBounds = true
        tv.rowHeight = 52
        return tv
    }()
    
    private var isOwner: Bool = false
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = RoomColors.settingBackground
        
        addSubview(backButtonContainerView)
        backButtonContainerView.addSubview(backButton)
        backButtonContainerView.addSubview(titleLabel)
        addSubview(sectionTitleLabel)
        addSubview(tableView)
    }
    
    private func setupConstraints() {
        backButtonContainerView.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.right.equalTo(titleLabel.snp.right).offset(20)
            make.height.equalTo(60)
        }
        
        backButton.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(22)
            make.width.height.equalTo(16)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(backButton.snp.right).offset(12)
            make.centerY.equalTo(backButton)
        }
        
        sectionTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(backButtonContainerView.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(sectionTitleLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.height.equalTo(52 * 3)
        }
    }
    
    private func setupBindings() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackTap))
        backButtonContainerView.addGestureRecognizer(tapGesture)
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(AITranscriptionSettingCell.self, forCellReuseIdentifier: AITranscriptionSettingCell.reuseIdentifier)
    }
    
    // MARK: - Public Methods
    
    public func bindRepository(_ repository: AITranscriberRepository) {
        self.repository = repository
        cancellables.removeAll()
        
        repository.$selectedSourceLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sourceLanguage in
                guard let self = self, let repo = self.repository else { return }
                updateRowDetail(at: 0, detail: repo.displayName(for: sourceLanguage))
            }
            .store(in: &cancellables)
        
        repository.$selectedTranslationLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] translationLanguage in
                guard let self = self, let repo = self.repository else { return }
                updateRowDetail(at: 1, detail: repo.displayName(for: translationLanguage))
            }
            .store(in: &cancellables)
        
        repository.$isBilingualEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOn in
                guard let self = self else { return }
                updateRowToggle(at: 2, isOn: isOn)
            }
            .store(in: &cancellables)
        
        RoomStore.shared.state.subscribe(StatePublisherSelector(keyPath: \.currentRoom))
            .receive(on: RunLoop.main)
            .sink { [weak self] roomInfo in
                guard let self = self else { return }
                if let ownerID = roomInfo?.roomOwner.userID, let selfUserID = LoginStore.shared.state.value.loginUserInfo?.userID {
                    isOwner = ownerID == selfUserID
                }
                buildRows()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    private func buildRows() {
        guard let repository = repository else { return }
        if isOwner {
            rows = [
                AITranscriptionSettingRowData(
                    title: .sourceLanguage,
                    detail: repository.displayName(for: repository.selectedSourceLanguage),
                    type: .alertSheet,
                    onTap: { [weak self] in
                        guard let self = self else { return }
                        showSourceLanguagePicker()
                    }
                ),
                AITranscriptionSettingRowData(
                    title: .translationLanguage,
                    detail: repository.displayName(for: repository.selectedTranslationLanguage),
                    type: .alertSheet,
                    onTap: { [weak self] in
                        guard let self = self else { return }
                        showTranslationLanguagePicker()
                    }
                ),
                AITranscriptionSettingRowData(
                    title: .bilingualSubtitle,
                    type: .toggle,
                    isOn: repository.isBilingualEnabled,
                    onToggle: { isOn in
                        repository.isBilingualEnabled = isOn
                    }
                ),
            ]
        } else {
           rows = [AITranscriptionSettingRowData(
                title: .bilingualSubtitle,
                type: .toggle,
                isOn: repository.isBilingualEnabled,
                onToggle: { isOn in
                    repository.isBilingualEnabled = isOn
                }
            )]
        }
        
        tableView.snp.remakeConstraints { make in
            make.top.equalTo(sectionTitleLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.height.equalTo(52 * rows.count)
        }
        
        tableView.reloadData()
    }
    
    private func showSourceLanguagePicker() {
        guard let repository = repository,
              let parent = self.superview ?? self.window else { return }
        
        let items = repository.sourceLanguageList.map { language in
            AITranscriptionPickerItem(
                title: repository.displayName(for: language),
                isSelected: language == repository.selectedSourceLanguage
            )
        }
        
        let picker = AITranscriptionPickerView(title: .selectSourceLanguage, items: items) { [weak self] index, _ in
            guard let self = self, let repo = self.repository else { return }
            let selectedLanguage = repo.sourceLanguageList[index]
            repo.updateTranscription(sourceLanguage: selectedLanguage)
        }
        picker.show(in: parent, animated: true)
    }
    
    private func showTranslationLanguagePicker() {
        guard let repository = repository,
              let parent = self.superview ?? self.window else { return }
        
        let items = repository.translationLanguageList.map { language in
            AITranscriptionPickerItem(
                title: repository.displayName(for: language),
                isSelected: language == repository.selectedTranslationLanguage
            )
        }
        
        let picker = AITranscriptionPickerView(title: .selectTranslationLanguage, items: items) { [weak self] index, _ in
            guard let self = self, let repo = self.repository else { return }
            let selectedLanguage = repo.translationLanguageList[index]
            repo.updateTranscription(translationLanguage: selectedLanguage)
        }
        picker.show(in: parent, animated: true)
    }
    
    private func updateRowDetail(at index: Int, detail: String) {
        guard index < rows.count else { return }
        rows[index].detail = detail
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }
    
    private func updateRowToggle(at index: Int, isOn: Bool) {
        guard index < rows.count else { return }
        rows[index].isOn = isOn
        tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
    }
    
    // MARK: - Actions
    
    @objc private func handleBackTap() {
        delegate?.settingViewDidTapBack(self)
    }
    
    private func showTooltip(text: String, anchorView: UIView) {
        dismissTooltip()
        
        let padding: CGFloat = 16
        let arrowSize = CGSize(width: 12, height: 6)
        
        // Bubble container
        let bubble = UIView()
        bubble.backgroundColor = .white
        bubble.layer.cornerRadius = 8
        
        let label = UILabel()
        label.text = text
        label.textColor = RoomColors.inRoomBackground
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.numberOfLines = 0
        
        bubble.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding))
        }
        
        let maxWidth = bounds.width - 32
        let labelSize = label.sizeThatFits(CGSize(width: maxWidth - 2 * padding, height: CGFloat.greatestFiniteMagnitude))
        let bubbleWidth = labelSize.width + 2 * padding
        let bubbleHeight = labelSize.height + 2 * padding
        
        // Arrow (triangle pointing down)
        let arrowLayer = CAShapeLayer()
        let arrowPath = UIBezierPath()
        arrowPath.move(to: CGPoint(x: 0, y: 0))
        arrowPath.addLine(to: CGPoint(x: arrowSize.width / 2, y: arrowSize.height))
        arrowPath.addLine(to: CGPoint(x: arrowSize.width, y: 0))
        arrowPath.close()
        arrowLayer.path = arrowPath.cgPath
        arrowLayer.fillColor = UIColor.white.cgColor
        
        // Tooltip wrapper
        let tooltipWrapper = UIView()
        tooltipWrapper.tag = 9999
        tooltipWrapper.layer.shadowColor = UIColor.black.cgColor
        tooltipWrapper.layer.shadowOpacity = 0.15
        tooltipWrapper.layer.shadowOffset = CGSize(width: 0, height: 2)
        tooltipWrapper.layer.shadowRadius = 8
        addSubview(tooltipWrapper)
        tooltipWrapper.addSubview(bubble)
        tooltipWrapper.layer.addSublayer(arrowLayer)
        
        // Calculate position
        let anchorRect = anchorView.convert(anchorView.bounds, to: self)
        let totalHeight = bubbleHeight + arrowSize.height
        let tooltipY = anchorRect.minY - totalHeight - 4
        var tooltipX = anchorRect.midX - bubbleWidth / 2
        tooltipX = max(16, min(tooltipX, bounds.width - bubbleWidth - 16))
        
        tooltipWrapper.frame = CGRect(x: tooltipX, y: tooltipY, width: bubbleWidth, height: totalHeight)
        bubble.frame = CGRect(x: 0, y: 0, width: bubbleWidth, height: bubbleHeight)
        
        let arrowCenterX = anchorRect.midX - tooltipX
        arrowLayer.frame = CGRect(x: arrowCenterX - arrowSize.width / 2, y: bubbleHeight, width: arrowSize.width, height: arrowSize.height)
        
        tooltipView = tooltipWrapper
        
        // Auto dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.dismissTooltip()
        }
    }
    
    private func dismissTooltip() {
        guard let tooltip = tooltipView else { return }
        UIView.animate(withDuration: 0.2, animations: {
            tooltip.alpha = 0
        }) { _ in
            tooltip.removeFromSuperview()
        }
        tooltipView = nil
    }
}

// MARK: - UITableViewDataSource

extension AITranscriptionSettingView: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AITranscriptionSettingCell.reuseIdentifier, for: indexPath) as? AITranscriptionSettingCell else {
            return UITableViewCell()
        }
        let rowData = rows[indexPath.row]
        cell.bindData(rowData, isLastRow: indexPath.row == rows.count - 1)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AITranscriptionSettingView: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let rowData = rows[indexPath.row]
        if rowData.type == .alertSheet {
            rowData.onTap?()
        }
    }
}

// MARK: - Localized Strings

fileprivate extension String {
    static let settingTitle = "roomkit_transcription_ai_subtitle_settings".localized
    static let sectionTitle = "roomkit_transcription_recognition_and_translation".localized
    static let sourceLanguage = "roomkit_transcription_identify_language".localized
    static let translationLanguage = "roomkit_transcription_translate_language".localized
    static let bilingualSubtitle = "roomkit_transcription_bilingual_subtitle".localized
    static let selectSourceLanguage = "roomkit_transcription_select_recognition_language".localized
    static let selectTranslationLanguage = "roomkit_transcription_select_translation_language".localized
    static let ownerOnlyTip = "roomkit_transcription_owner_only_modify_language".localized
}

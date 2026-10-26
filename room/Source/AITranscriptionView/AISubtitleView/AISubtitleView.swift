//
//  AISubtitleView.swift
//  AISubtitle
//

import UIKit
import Combine
import SnapKit
import AtomicXCore

/// Multi-speaker subtitle list view. StackView-based, auto-sizing via intrinsicContentSize.
/// Displays up to `maxVisibleSpeakers` subtitle items with auto-fade support.
public class AISubtitleView: UIView {
    
    // MARK: - Properties
    
    private var config: AISubtitleConfig = .default
    private weak var repository: AITranscriberRepository?
    private var cancellables = Set<AnyCancellable>()
    
    private var activeSegmentKeys: [String] = []
    private var fadeOutWorkItems: [String: DispatchWorkItem] = [:]
    
    /// Map from segmentId to its item view.
    private var itemViews: [String: AISubtitleItemView] = [:]
    
    public var onSubtitleFadeOut: ((String) -> Void)?
    public var onTap: (() -> Void)?
    
    private var placeholderTopConstraint: Constraint?
    private var placeholderBottomConstraint: Constraint?
    private var placeholderHeightConstraint: Constraint?
    private var contentStackTopConstraint: Constraint?
    private var contentStackBottomConstraint: Constraint?
    
    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = .placeholderText
        label.textColor = .white
        label.font = RoomFonts.pingFangSCFont(size: 14, weight: .regular)
        label.textAlignment = .center
        return label
    }()
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        return stack
    }()
    
    private let arrowImageView: UIImageView = {
        let imageView = UIImageView(image: ResourceLoader.loadImage("room_ai_subtitle_right_arrow"))
        return imageView
    }()
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        fadeOutWorkItems.values.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        clipsToBounds = true
        isUserInteractionEnabled = true
        
        addSubview(placeholderLabel)
        addSubview(contentStack)
        addSubview(arrowImageView)
        
        placeholderLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            placeholderHeightConstraint = make.height.equalTo(40).constraint
            placeholderTopConstraint = make.top.equalToSuperview().constraint
            placeholderBottomConstraint = make.bottom.equalToSuperview().constraint
        }
        
        contentStack.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.right.equalTo(arrowImageView.snp.left).offset(-4)
            contentStackTopConstraint = make.top.equalToSuperview().constraint
            contentStackBottomConstraint = make.bottom.equalToSuperview().constraint
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalToSuperview().offset(-4)
        }
        
        applyConfig(config)
        updatePlaceholderVisibility()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.cancelsTouchesInView = false
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap() {
        onTap?()
    }
    
    // MARK: - Configuration
    
    public func bindRepository(_ repository: AITranscriberRepository) {
        self.repository = repository
        cancellables.removeAll()
        
        repository.subtitleEventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                handleEvent(event)
            }
            .store(in: &cancellables)
        
        repository.$isBilingualEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isBilingual in
                guard let self = self, let repo = self.repository else { return }
                config.displayMode = resolveDisplayMode(isBilingual: isBilingual, translationLanguage: repo.selectedTranslationLanguage)
                reloadAllItems()
            }
            .store(in: &cancellables)
        
        repository.$selectedTranslationLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] translationLanguage in
                guard let self = self, let repo = self.repository else { return }
                config.displayMode = resolveDisplayMode(isBilingual: repo.isBilingualEnabled, translationLanguage: translationLanguage)
                reloadAllItems()
            }
            .store(in: &cancellables)
    }
    
    public func configure(with config: AISubtitleConfig) {
        self.config = config
        applyConfig(config)
        reloadAllItems()
    }
    
    // MARK: - Display Mode

    private func resolveDisplayMode(isBilingual: Bool, translationLanguage: TranslationLanguage?) -> DisplayMode {
        if translationLanguage == nil { return .sourceOnly }
        return isBilingual ? .dual : .translationOnly
    }

    // MARK: - Event Handling
    
    private func handleEvent(_ event: AISubtitleDataEvent) {
        switch event {
        case .added(let data):
            handleAdded(data)
        case .updated(let data):
            handleUpdated(data)
        case .completed(let data):
            if let itemView = itemViews[data.segmentId] {
                itemView.bindData(data, config: config)
            }
            if config.displayDuration > 0 {
                scheduleFadeOut(for: data.segmentId)
            }
        case .clearedAll:
            clearAll(animated: true)
        }
    }
    
    // MARK: - Public Methods
    
    public func removeSubtitle(_ segmentId: String, animated: Bool = true) {
        cancelFadeOutTimer(for: segmentId)
        
        activeSegmentKeys.removeAll { $0 == segmentId }
        
        guard let itemView = itemViews.removeValue(forKey: segmentId) else {
            updatePlaceholderVisibility()
            onSubtitleFadeOut?(segmentId)
            return
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                itemView.alpha = 0
            }, completion: { [weak self] _ in
                itemView.removeFromSuperview()
                self?.updateAllItemMaxLines()
                self?.updatePlaceholderVisibility()
            })
        } else {
            itemView.removeFromSuperview()
            updateAllItemMaxLines()
            updatePlaceholderVisibility()
        }
        onSubtitleFadeOut?(segmentId)
    }
    
    public func clearAll(animated: Bool = true) {
        fadeOutWorkItems.values.forEach { $0.cancel() }
        fadeOutWorkItems.removeAll()
        activeSegmentKeys.removeAll()
        
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                self.contentStack.arrangedSubviews.forEach {
                    $0.alpha = 0
                }
            }, completion: { _ in
                self.contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
                self.itemViews.removeAll()
                self.updatePlaceholderVisibility()
            })
        } else {
            contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            itemViews.removeAll()
            updatePlaceholderVisibility()
        }
    }
    
    public var activeSegmentCount: Int {
        return activeSegmentKeys.count
    }
    
    // MARK: - Private Methods
    
    private func applyConfig(_ config: AISubtitleConfig) {
        backgroundColor = config.backgroundColor
        layer.cornerRadius = config.backgroundCornerRadius
        contentStack.spacing = config.speakerItemSpacing
    }
    
    private func updatePlaceholderVisibility() {
        let hasSubtitles = !activeSegmentKeys.isEmpty
        placeholderLabel.isHidden = hasSubtitles
        contentStack.isHidden = !hasSubtitles
        arrowImageView.isHidden = !hasSubtitles
        
        if hasSubtitles {
            placeholderTopConstraint?.deactivate()
            placeholderBottomConstraint?.deactivate()
            placeholderHeightConstraint?.deactivate()
            contentStackTopConstraint?.activate()
            contentStackBottomConstraint?.activate()
        } else {
            contentStackTopConstraint?.deactivate()
            contentStackBottomConstraint?.deactivate()
            placeholderTopConstraint?.activate()
            placeholderBottomConstraint?.activate()
            placeholderHeightConstraint?.activate()
        }
    }
    
    private func handleAdded(_ data: AITranscriptionData) {
        let segmentId = data.segmentId
        cancelFadeOutTimer(for: segmentId)
        activeSegmentKeys.append(segmentId)
        trimExcessSegments()
        rebuildStackItems()
        updatePlaceholderVisibility()
        
        if config.displayDuration > 0 {
            scheduleFadeOut(for: segmentId)
        }
    }
    
    private func handleUpdated(_ data: AITranscriptionData) {
        let segmentId = data.segmentId
        cancelFadeOutTimer(for: segmentId)
        
        if !activeSegmentKeys.contains(segmentId) {
            activeSegmentKeys.append(segmentId)
            trimExcessSegments()
            rebuildStackItems()
            updatePlaceholderVisibility()
        } else {
            moveToLatest(segmentId: segmentId)
            if let itemView = itemViews[segmentId] {
                itemView.bindData(data, config: config)
                itemView.updateMaxLines(maxLinesForCurrentLayout())
            }
        }
        if config.displayDuration > 0 {
            scheduleFadeOut(for: segmentId)
        }
    }
    
    private func visibleSegmentKeys() -> [String] {
        let max = config.maxVisibleSpeakers
        guard max > 0, activeSegmentKeys.count > max else { return activeSegmentKeys }
        return Array(activeSegmentKeys.suffix(max))
    }
    
    private func trimExcessSegments() {
        let max = config.maxVisibleSpeakers
        guard max > 0 else { return }
        while activeSegmentKeys.count > max {
            let removed = activeSegmentKeys.removeFirst()
            cancelFadeOutTimer(for: removed)
            if let itemView = itemViews.removeValue(forKey: removed) {
                itemView.removeFromSuperview()
            }
        }
    }
    
    private func moveToLatest(segmentId: String) {
        guard let index = activeSegmentKeys.firstIndex(of: segmentId) else { return }
        let oldVisible = visibleSegmentKeys()
        activeSegmentKeys.remove(at: index)
        activeSegmentKeys.append(segmentId)
        let newVisible = visibleSegmentKeys()
        
        if oldVisible != newVisible {
            rebuildStackItems()
        }
    }
    
    /// Update maxLines for all visible items based on current speaker count.
    private func updateAllItemMaxLines() {
        let maxLines = maxLinesForCurrentLayout()
        for (_, itemView) in itemViews {
            itemView.updateMaxLines(maxLines)
        }
    }
    
    /// Returns the max number of lines per subtitle text based on how many speakers are visible.
    /// 1 speaker → 2 lines; 2+ speakers → 1 line.
    private func maxLinesForCurrentLayout() -> Int {
        let visibleCount = visibleSegmentKeys().count
        return visibleCount <= 1 ? 2 : 1
    }
    
    /// Rebuild all arranged subviews from visible segment keys.
    private func rebuildStackItems() {
        let visible = visibleSegmentKeys()
        let maxLines = maxLinesForCurrentLayout()
        
        // Remove all current arranged subviews
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add items in order
        for segmentId in visible {
            let itemView: AISubtitleItemView
            if let existing = itemViews[segmentId] {
                itemView = existing
            } else {
                itemView = AISubtitleItemView()
                itemViews[segmentId] = itemView
            }
            
            if let data = repository?.getData(for: segmentId) {
                itemView.bindData(data, config: config)
            }
            itemView.updateMaxLines(maxLines)
            contentStack.addArrangedSubview(itemView)
        }
        
        // Clean up itemViews for segments no longer visible
        let visibleSet = Set(visible)
        for key in itemViews.keys where !visibleSet.contains(key) {
            itemViews[key]?.removeFromSuperview()
            itemViews.removeValue(forKey: key)
        }
    }
    
    /// Reload all visible items with current config.
    private func reloadAllItems() {
        let visible = visibleSegmentKeys()
        for segmentId in visible {
            if let data = repository?.getData(for: segmentId),
               let itemView = itemViews[segmentId] {
                itemView.bindData(data, config: config)
            }
        }
    }
    
    // MARK: - Fade Out Timer
    
    private func scheduleFadeOut(for segmentId: String) {
        cancelFadeOutTimer(for: segmentId)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            fadeOutWorkItems.removeValue(forKey: segmentId)
            removeSubtitle(segmentId, animated: true)
        }
        fadeOutWorkItems[segmentId] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + config.displayDuration, execute: workItem)
    }
    
    private func cancelFadeOutTimer(for segmentId: String) {
        fadeOutWorkItems[segmentId]?.cancel()
        fadeOutWorkItems.removeValue(forKey: segmentId)
    }
}

extension String {
    fileprivate static let placeholderText = "roomkit_transcription_ai_subtitle_placeholder".localized
}

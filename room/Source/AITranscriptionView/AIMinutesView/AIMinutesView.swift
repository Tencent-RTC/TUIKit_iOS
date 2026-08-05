//
//  AIMinutesView.swift
//  AIMinutesView
//

import UIKit
import Combine
import SnapKit
import AtomicXCore

// MARK: - Delegate

public protocol AIMinutesViewDelegate: AnyObject {
    func minutesViewDidTapBack(_ minutesView: AIMinutesView)
}

// MARK: - AIMinutesView

/// Scrollable list view displaying all AI transcription minutes entries.
public class AIMinutesView: UIView {
    
    // MARK: - Properties
    
    private var config: AIMinutesConfig = .default
    public weak var delegate: AIMinutesViewDelegate?
    private weak var repository: AITranscriberRepository?
    private var cancellables = Set<AnyCancellable>()
    private var segmentIds: [String] = []
    private var segmentIndexMap: [String: Int] = [:]
    
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
        label.text = .minutesTitle
        label.font = RoomFonts.pingFangSCFont(size: 16, weight: .medium)
        label.textColor = RoomColors.g2
        return label
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = true
        tableView.showsHorizontalScrollIndicator = false
        tableView.keyboardDismissMode = .onDrag
        tableView.alwaysBounceHorizontal = false
        return tableView
    }()
    
    private var isUserDragging: Bool = false
    private var isNearBottom: Bool = true
    
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
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(backButtonContainerView)
        backButtonContainerView.addSubview(backButton)
        backButtonContainerView.addSubview(titleLabel)
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
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(backButtonContainerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    private func setupBindings() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackTap))
        backButtonContainerView.addGestureRecognizer(tapGesture)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(AIMinutesCell.self, forCellReuseIdentifier: AIMinutesCell.reuseIdentifier)
    }
    
    // MARK: - Configuration
    
    /// Bind a repository to subscribe to subtitle events and sync existing data.
    public func bindRepository(_ repository: AITranscriberRepository) {
        self.repository = repository
        cancellables.removeAll()
        
        syncFromRepository()
        
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
                tableView.reloadData()
            }
            .store(in: &cancellables)
        
        repository.$selectedTranslationLanguage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] translationLanguage in
                guard let self = self, let repo = self.repository else { return }
                config.displayMode = resolveDisplayMode(isBilingual: repo.isBilingualEnabled, translationLanguage: translationLanguage)
                tableView.reloadData()
            }
            .store(in: &cancellables)
    }
    
    public func configure(with config: AIMinutesConfig) {
        self.config = config
        backgroundColor = config.backgroundColor
        
        tableView.contentInset = UIEdgeInsets(top: config.listContentInsets.top,
                                               left: 0,
                                               bottom: config.listContentInsets.bottom,
                                               right: 0)
        tableView.reloadData()
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
            let index = segmentIds.count
            segmentIds.append(data.segmentId)
            segmentIndexMap[data.segmentId] = index
            
            tableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .fade)
            if isNearBottom && !isUserDragging {
                scrollToBottom(animated: true)
            }
            
        case .updated(let data):
            updateCell(for: data)
            
        case .completed(let data):
            updateCell(for: data)
            
        case .clearedAll:
            segmentIds.removeAll()
            segmentIndexMap.removeAll()
            tableView.reloadData()
        }
    }
    
    private func updateCell(for data: AITranscriptionData) {
        guard let index = segmentIndexMap[data.segmentId] else { return }
        let indexPath = IndexPath(row: index, section: 0)
        if let cell = tableView.cellForRow(at: indexPath) as? AIMinutesCell {
            cell.updateTexts(data, config: config)
        }
        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            tableView.endUpdates()
        }
        if isNearBottom && !isUserDragging {
            scrollToBottom(animated: false)
        }
    }
    
    // MARK: - Public Methods
    
    public var minutesCount: Int {
        return segmentIds.count
    }
    
    public func scrollToBottom(animated: Bool) {
        guard !segmentIds.isEmpty else { return }
        let indexPath = IndexPath(row: segmentIds.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
    
    public func clearAll() {
        segmentIds.removeAll()
        segmentIndexMap.removeAll()
        tableView.reloadData()
    }
    
    // MARK: - Private
    
    /// Determines whether the cell at the given row should display speaker name and timestamp.
    /// Returns `false` when the previous cell belongs to the same speaker and the time gap is ≤ 60 seconds.
    private func shouldShowSpeakerInfo(at row: Int, currentData: AITranscriptionData) -> Bool {
        guard row > 0 else { return true }
        let previousSegmentId = segmentIds[row - 1]
        guard let previousData = repository?.getData(for: previousSegmentId) else { return true }
        
        let isSameSpeaker = previousData.speakerUserId == currentData.speakerUserId
        let timeDiffMs = abs(currentData.timestamp - previousData.timestamp)
        let isWithin60Seconds = timeDiffMs <= 60_000
        
        return !(isSameSpeaker && isWithin60Seconds)
    }
    
    /// Sync snapshot from repository (for late-binding: minutes page opened after subtitles started).
    private func syncFromRepository() {
        guard let repository = repository else { return }
        segmentIds = repository.orderedSegmentIds
        segmentIndexMap.removeAll()
        for (index, id) in segmentIds.enumerated() {
            segmentIndexMap[id] = index
        }
        tableView.reloadData()
        
        if !segmentIds.isEmpty {
            DispatchQueue.main.async {
                self.scrollToBottom(animated: false)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleBackTap() {
        delegate?.minutesViewDidTapBack(self)
    }
}

// MARK: - UITableViewDataSource

extension AIMinutesView: UITableViewDataSource {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return segmentIds.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AIMinutesCell.reuseIdentifier, for: indexPath) as? AIMinutesCell else {
            return UITableViewCell()
        }
        let segmentId = segmentIds[indexPath.row]
        if let data = repository?.getData(for: segmentId) {
            let showSpeakerInfo = shouldShowSpeakerInfo(at: indexPath.row, currentData: data)
            cell.bindData(data, config: config, showSpeakerInfo: showSpeakerInfo)
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AIMinutesView: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserDragging = true
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateAutoScrollState(scrollView)
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateAutoScrollState(scrollView)
    }
    
    private func updateAutoScrollState(_ scrollView: UIScrollView) {
        isUserDragging = false
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.height
        let bottomInset = scrollView.contentInset.bottom
        let distanceFromBottom = contentHeight - offsetY - frameHeight + bottomInset
        isNearBottom = distanceFromBottom <= 40
    }
}

fileprivate extension String {
    static let minutesTitle = "roomkit_transcription_ai_minutes_title".localized
}

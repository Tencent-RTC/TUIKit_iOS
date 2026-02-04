//
//  TranscriberView.swift
//  AtomicX
//
//  Created on 2026/1/19.
//

import UIKit
import SnapKit
import AtomicXCore
import Combine

public enum TranscriberSettings {
    public static var config: TranscriberConfig = .default
    public static var isBilingualEnabled: Bool = true
    
    public static func reset() {
        config = .default
        isBilingualEnabled = true
    }
}

public extension TranscriberConfig {
    static let `default` = TranscriberConfig(
        sourceLanguage: .chineseEnglish,
        translationLanguages: [.english]
    )
}

final class TranscriberView: UIView {
    
    private static var minHeight: CGFloat { 80.scale375Height() }
    private static var maxHeight: CGFloat { 136.scale375Height() }
    
    private var isUserScrolling = false
    private var cancellables = Set<AnyCancellable>()
    private var messages: [TranscriberMessage] = []
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(0x000000, alpha: 0.5)
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tableView.register(TranscriberMessageCell.self, forCellReuseIdentifier: TranscriberMessageCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        return tableView
    }()
    
    private lazy var arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.right")
        imageView.tintColor = UIColor(0xFFFFFF, alpha: 0.4)
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = !isCaller
        return imageView
    }()
    
    private var isCaller: Bool {
        let state = CallStore.shared.state.value
        return state.selfInfo.id == state.activeCall.inviterId
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func clearMessages() {
        messages = []
        tableView.reloadData()
        invalidateIntrinsicContentSize()
    }
    
    private func constructViewHierarchy() {
        addSubview(containerView)
        containerView.addSubview(tableView)
        containerView.addSubview(arrowImageView)
    }
    
    private func activateConstraints() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(Self.minHeight)
            make.height.lessThanOrEqualTo(Self.maxHeight)
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-12)
            make.size.equalTo(CGSize(width: 8, height: 14))
        }
        
        tableView.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
            make.trailing.equalToSuperview().offset(isCaller ? -28 : -12)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        let contentHeight = tableView.contentSize.height + tableView.contentInset.top + tableView.contentInset.bottom
        let clampedHeight = min(max(contentHeight, Self.minHeight), Self.maxHeight)
        return CGSize(width: UIView.noIntrinsicMetric, height: clampedHeight)
    }
    
    private func bindInteraction() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onContainerTapped))
        containerView.addGestureRecognizer(tapGesture)
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            observeMessages()
        } else {
            cancellables.removeAll()
        }
    }
    
    private func observeMessages() {
        AITranscriberStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \.realtimeMessageList))
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.updateMessages($0) }
            .store(in: &cancellables)
    }
    
    private func updateMessages(_ newMessages: [TranscriberMessage]) {
        let shouldScroll = !newMessages.isEmpty && !isUserScrolling
        messages = newMessages
        tableView.reloadData()
        invalidateIntrinsicContentSize()
        
        guard shouldScroll else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.messages.isEmpty else { return }
            let lastIndex = IndexPath(row: self.messages.count - 1, section: 0)
            self.tableView.scrollToRow(at: lastIndex, at: .bottom, animated: false)
        }
    }
    
    @objc private func onContainerTapped() {
        guard isCaller, let viewController = findViewController() else { return }
        TranscriberSettingsViewController.show(from: viewController) { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }
    
    private func getDisplayName(for message: TranscriberMessage) -> String {
        let isSelf = message.speakerUserId == LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let meText = isSelf ? " \(CallKitBundle.localizedString(forKey: "ai_transcriber_me"))" : ""
        let name = message.speakerUserName.isEmpty ? message.speakerUserId : message.speakerUserName
        return "\(name)\(meText)"
    }
}

extension TranscriberView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TranscriberMessageCell.reuseIdentifier,
                                                       for: indexPath) as? TranscriberMessageCell else {
            return UITableViewCell()
        }
        let message = messages[indexPath.row]
        let prevMessage = indexPath.row > 0 ? messages[indexPath.row - 1] : nil
        cell.configure(
            message: message,
            displayName: getDisplayName(for: message),
            showUserName: message.speakerUserId != prevMessage?.speakerUserId,
            isBilingualEnabled: TranscriberSettings.isBilingualEnabled
        )
        return cell
    }
}

extension TranscriberView: UITableViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserScrolling = true
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if isAtBottom { isUserScrolling = false }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate && isAtBottom { isUserScrolling = false }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if isAtBottom { isUserScrolling = false }
    }
    
    private var isAtBottom: Bool {
        guard !messages.isEmpty else { return true }
        let lastVisibleRow = tableView.indexPathsForVisibleRows?.last?.row ?? 0
        return lastVisibleRow >= messages.count - 2
    }
}

private final class TranscriberMessageCell: UITableViewCell {
    static let reuseIdentifier = "TranscriberMessageCell"
    
    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(0xFFFFFF, alpha: 0.75)
        label.font = .systemFont(ofSize: 14)
        return label
    }()
    
    private let sourceTextLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        return label
    }()
    
    private let translationTextLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(0xFFFFFF, alpha: 0.9)
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        return label
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .fill
        return stack
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        constructViewHierarchy()
        activateConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func constructViewHierarchy() {
        contentView.addSubview(stackView)
        [userNameLabel, sourceTextLabel, translationTextLabel].forEach { stackView.addArrangedSubview($0) }
    }
    
    private func activateConstraints() {
        stackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-8)
            make.top.equalToSuperview().offset(6)
            make.bottom.equalToSuperview().offset(-6)
        }
    }
    
    func configure(message: TranscriberMessage, displayName: String, showUserName: Bool, isBilingualEnabled: Bool) {
        userNameLabel.text = displayName
        userNameLabel.isHidden = !showUserName
        
        let translationText = message.translationTexts.values.first ?? ""
        let shouldShowBilingual = isBilingualEnabled && !translationText.isEmpty && message.sourceText != translationText
        
        sourceTextLabel.text = message.sourceText
        sourceTextLabel.isHidden = !shouldShowBilingual
        
        translationTextLabel.text = translationText.isEmpty ? message.sourceText : translationText
    }
}

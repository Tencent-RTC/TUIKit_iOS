import UIKit

final class AICallTranscriptView: UITableView {
    private static let pinThreshold: CGFloat = 40

    private static let progressKeyPrefix = "aicall_"

    private var entries: [AICallTranscriptEntry] = []
    private var pacedMessageKeys: Set<String> = []
    private var contentSizeObservation: NSKeyValueObservation?
    private var isPinnedToBottom = true
    private var isUserDragging = false

    deinit {
        for key in pacedMessageKeys {
            StreamingMarkdownView.discardProgress(msgID: key)
        }
    }

    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: .plain)
        backgroundColor = .clear
        separatorStyle = .none
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        alwaysBounceHorizontal = false
        isDirectionalLockEnabled = true
        contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        register(AICallTranscriptCell.self, forCellReuseIdentifier: AICallTranscriptCell.reuseID)
        dataSource = self
        delegate = self
        contentSizeObservation = observe(\.contentSize, options: [.new]) { [weak self] _, _ in
            self?.pinToBottom()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        pinToBottom()
    }

    func submit(_ newEntries: [AICallTranscriptEntry]) {
        entries = newEntries
        for entry in newEntries where !entry.isUser {
            if let key = Self.progressKey(of: entry) {
                pacedMessageKeys.insert(key)
            }
        }
        reloadData()
        layoutIfNeeded()
        pinToBottom()
        DispatchQueue.main.async { [weak self] in
            self?.pinToBottom()
        }
    }

    private func pinToBottom() {
        guard !entries.isEmpty, bounds.height > 0 else { return }
        guard isPinnedToBottom, !isUserDragging, !isDecelerating else { return }
        let maxOffsetY = contentSize.height - bounds.height + adjustedContentInset.bottom
        guard maxOffsetY > -adjustedContentInset.top else { return }
        if contentOffset.y != maxOffsetY {
            setContentOffset(CGPoint(x: 0, y: maxOffsetY), animated: false)
        }
    }

    fileprivate static func progressKey(of entry: AICallTranscriptEntry) -> String? {
        guard let msgID = entry.msgID, !msgID.isEmpty else { return nil }
        return progressKeyPrefix + msgID
    }

    fileprivate func refreshRowHeights() {
        UIView.performWithoutAnimation {
            beginUpdates()
            endUpdates()
        }
    }

    private func updatePinState() {
        let distanceFromBottom = contentSize.height - (contentOffset.y + bounds.height)
        isPinnedToBottom = distanceFromBottom <= Self.pinThreshold
    }
}

extension AICallTranscriptView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AICallTranscriptCell.reuseID, for: indexPath) as! AICallTranscriptCell
        cell.configure(entries[indexPath.row], availableWidth: tableView.bounds.width) { [weak self] in
            self?.refreshRowHeights()
        }
        return cell
    }
}

extension AICallTranscriptView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard indexPath.row == entries.count - 1 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.pinToBottom()
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserDragging = true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        isUserDragging = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updatePinState()
    }
}

private final class AICallTranscriptCell: UITableViewCell {
    static let reuseID = "AICallTranscriptCell"

    private static let userTextColor = UIColor(red: 0x8A / 255.0, green: 0x90 / 255.0, blue: 0x99 / 255.0, alpha: 1)
    private static let assistantTextColor = UIColor(red: 0xF2 / 255.0, green: 0xF4 / 255.0, blue: 0xF6 / 255.0, alpha: 1)
    private static let failedTextColor = UIColor(red: 1.0, green: 0x5A / 255.0, blue: 0x5F / 255.0, alpha: 1)
    private static let verticalPadding: CGFloat = 6
    private static let horizontalPadding: CGFloat = 24
    private static let fontSize: CGFloat = 16
    private static let layoutKey = "aicall_transcript"

    private let contentLabel = UILabel()
    private let markdownView = StreamingMarkdownView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentLabel.font = .systemFont(ofSize: Self.fontSize)
        contentLabel.numberOfLines = 0
        contentView.addSubview(contentLabel)
        contentView.addSubview(markdownView)
        pin(contentLabel)
        pin(markdownView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        markdownView.recycle()
        markdownView.onDisplayedHeightChange = nil
    }

    func configure(_ entry: AICallTranscriptEntry, availableWidth: CGFloat, onHeightChange: @escaping () -> Void) {
        let showsMarkdown = !entry.isUser && !entry.isFailed
        contentLabel.isHidden = showsMarkdown
        markdownView.isHidden = !showsMarkdown
        guard showsMarkdown else {
            markdownView.recycle()
            contentLabel.attributedText = nil
            contentLabel.text = entry.text
            contentLabel.textColor = entry.isFailed ? Self.failedTextColor : Self.userTextColor
            return
        }
        contentLabel.text = nil
        markdownView.onDisplayedHeightChange = onHeightChange
        let containerWidth = availableWidth > 0 ? availableWidth : UIScreen.main.bounds.width
        markdownView.bind(
            msgID: AICallTranscriptView.progressKey(of: entry) ?? "",
            markdown: entry.text,
            isStreaming: entry.isStreaming,
            textColor: Self.assistantTextColor,
            maxTextWidth: max(0, containerWidth - Self.horizontalPadding * 2),
            layoutKey: Self.layoutKey,
            revealLimiter: entry.speechProgress
        )
    }

    private func pin(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Self.verticalPadding),
            view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Self.verticalPadding),
            view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.horizontalPadding),
            view.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -Self.horizontalPadding),
        ])
    }
}

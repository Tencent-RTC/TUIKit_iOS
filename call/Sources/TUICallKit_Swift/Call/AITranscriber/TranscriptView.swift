import AtomicXCore
import Combine
import SnapKit
import UIKit

final class TranscriptView: UIView {

    enum LayoutMode {
        case single
        case multi(rows: Int)

        var listMaxHeight: CGFloat {
            switch self {
            case .single: return 140
            case .multi(let rows): return rows >= 3 ? 139 : 70
            }
        }
    }

    var layoutMode: LayoutMode = .single {
        didSet { updateHeight() }
    }

    var isImmersiveExpanded = false {
        didSet { updateHeight() }
    }

    var onPickSettings: (() -> Void)?
    var onTap: (() -> Void)?

    private let scrollView = UIScrollView()
    private let listStack = UIStackView()
    private let headContainer = UIView()
    private let gearButton = UIButton(type: .system)
    private var heightConstraint: Constraint?
    private var cancellables = Set<AnyCancellable>()
    private var transcriberCancellable: AnyCancellable?
    private var subscribedCallId = ""
    private var messages: [TranscriberMessage] = []

    private static let minBlockHeight: CGFloat = 78
    private static let headRowHeight: CGFloat = 28
    private static let headRowGap: CGFloat = 8
    private static let headBlockHeight: CGFloat = headRowHeight + headRowGap

    private var maxListHeight: CGFloat {
        if isImmersiveExpanded {
            let base = superview?.bounds.height ?? UIScreen.main.bounds.height
            switch layoutMode {
            case .single: return base * (325.0 / 852.0)
            case .multi: return base * (343.0 / 852.0)
            }
        }
        return layoutMode.listMaxHeight
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        subscribeState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeight()
    }



    private func setupViews() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)
        setupHeadRow()

        listStack.axis = .vertical
        listStack.spacing = 8
        listStack.alignment = .leading

        scrollView.indicatorStyle = .white
        scrollView.addSubview(listStack)
        listStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(headContainer.snp.bottom).offset(Self.headRowGap)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupHeadRow() {
        headContainer.isUserInteractionEnabled = false
        addSubview(headContainer)
        headContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Self.headRowHeight)
        }

        let titleLabel = UILabel()
        titleLabel.text = CallKitResources.text("callkit.cc.title")
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .white
        headContainer.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(2)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(headContainer.snp.trailing).offset(-32)
        }

        gearButton.isUserInteractionEnabled = true
        gearButton.setImage(CallKitResources.image(named: "callkit_icon_settings")?.withRenderingMode(.alwaysTemplate), for: .normal)
        gearButton.tintColor = .white
        gearButton.imageView?.contentMode = .scaleAspectFit
        gearButton.imageEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        gearButton.accessibilityLabel = CallKitResources.text("callkit.cc.title")
        gearButton.addAction(UIAction { [weak self] _ in self?.onPickSettings?() }, for: .touchUpInside)
        addSubview(gearButton)
        gearButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-2)
            make.centerY.equalTo(headContainer.snp.centerY)
            make.size.equalTo(28)
        }
    }

    private var targetHeight: CGFloat {
        let content = scrollView.contentSize.height
        let minHeight = min(Self.minBlockHeight, maxListHeight)
        let listHeight = min(max(content, minHeight), maxListHeight)
        return listHeight + Self.headBlockHeight
    }

    private func updateHeight() {
        let target = targetHeight
        let current = heightConstraint?.layoutConstraints.first?.constant ?? -1
        if abs(current - target) > 0.5 {
            heightConstraint?.update(offset: target)
        }
    }

    func remakeHeightConstraint(in make: ConstraintMaker) {
        heightConstraint = make.height.equalTo(targetHeight).priority(.high).constraint
    }

    private func subscribeState() {
        CallStore.shared.state
            .subscribe(StatePublisherSelector { $0.activeCall.callId })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] callId in self?.subscribeTranscriber(callId: callId) }
            .store(in: &cancellables)

        CallKitConfig.shared.transcriptionChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.renderAll() }
            .store(in: &cancellables)
    }

    private func subscribeTranscriber(callId: String) {
        guard callId != subscribedCallId else { return }
        subscribedCallId = callId
        transcriberCancellable = nil
        messages = []
        renderAll()
        guard !callId.isEmpty else { return }
        let store = AITranscriberStore.create(roomID: callId)
        transcriberCancellable = store.state
            .subscribe(StatePublisherSelector { $0.realtimeMessageList })
            .receive(on: RunLoop.main)
            .sink { [weak self] list in self?.applyMessages(list) }
    }

    private func applyMessages(_ list: [TranscriberMessage]) {
        if list.count == messages.count,
           let last = list.last, let current = messages.last,
           last.segmentId == current.segmentId, !last.isCompleted {
            messages[messages.count - 1] = last
            updateRow(at: messages.count - 1)
            scrollToBottom()
            return
        }
        messages = list
        renderAll()
    }

    private func renderAll() {
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        messages.forEach { listStack.addArrangedSubview(makeRow(message: $0)) }
        updateHeight()
        scrollToBottom()
    }

    private func updateRow(at index: Int) {
        guard index < listStack.arrangedSubviews.count else {
            renderAll()
            return
        }
        let row = makeRow(message: messages[index])
        let old = listStack.arrangedSubviews[index]
        listStack.insertArrangedSubview(row, at: index)
        old.removeFromSuperview()
        updateHeight()
    }

    private func makeRow(message: TranscriberMessage) -> UIView {
        let config = CallKitConfig.shared
        let fontSize = config.transcriptFontSize.textFontSize

        let speakerLabel = UILabel()
        speakerLabel.attributedText = Self.lineText(message.speakerUserName.isEmpty ? message.speakerUserId : message.speakerUserName,
                                                    font: .systemFont(ofSize: fontSize, weight: .semibold),
                                                    color: CallKitTheme.brand,
                                                    lineBreak: .byTruncatingTail)

        let textLabel = UILabel()
        let display = displayText(for: message)
        textLabel.attributedText = Self.lineText(display, font: .systemFont(ofSize: fontSize), color: .white)

        let line = UIStackView(arrangedSubviews: [speakerLabel, textLabel])
        line.spacing = 8
        line.alignment = .top

        let row = UIStackView(arrangedSubviews: [line])
        row.axis = .vertical
        row.spacing = 2

        if config.showOriginalTranscript, display != message.sourceText {
            let sourceLabel = UILabel()
            sourceLabel.attributedText = Self.lineText(message.sourceText,
                                                       font: .systemFont(ofSize: 11),
                                                       color: UIColor.white.withAlphaComponent(0.62),
                                                       lineHeight: 15)
            sourceLabel.numberOfLines = 0
            row.addArrangedSubview(sourceLabel)
        }

        textLabel.numberOfLines = 0
        speakerLabel.setContentHuggingPriority(.required, for: .horizontal)
        speakerLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return row
    }

    private static func lineText(_ text: String, font: UIFont, color: UIColor, lineHeight: CGFloat = 18, lineBreak: NSLineBreakMode = .byWordWrapping) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineHeight
        style.maximumLineHeight = lineHeight
        style.lineBreakMode = lineBreak
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style,
        ])
    }

    private func displayText(for message: TranscriberMessage) -> String {
        if let target = targetLanguage, let text = message.translationTexts[target], !text.isEmpty {
            return text
        }
        return message.sourceText
    }

    private var targetLanguage: TranslationLanguage? {
        switch CallKitConfig.shared.transcriptionTargetLanguage {
        case "zh": return .chinese
        case "en": return .english
        case "ar": return .arabic
        case "ja": return .japanese
        default: return nil
        }
    }

    @objc private func handleTap() {
        onTap?()
    }

    private func scrollToBottom() {
        layoutIfNeeded()
        let offsetY = max(scrollView.contentSize.height - scrollView.bounds.height, 0)
        scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
    }
}

extension TranscriptView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view === gearButton || touch.view?.isDescendant(of: gearButton) == true)
    }
}

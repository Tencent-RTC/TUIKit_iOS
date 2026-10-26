import UIKit
import SnapKit
import AtomicXCore

/// 「Markdown 文本 + 三点加载动画」气泡，供逐步生成的消息共用。
/// 对齐 Android StreamingTextContentView：chatbotPlugin 消息与 TIMStreamElem 流式消息都用它。
final class MessageStreamingContentView: UIView, MessageContentView {
    private static let horizontalPadding: CGFloat = 12
    private static let verticalPadding: CGFloat = 8
    private static let dotsSpacing: CGFloat = 4
    private static let dotsSize = CGSize(width: 24, height: 20)

    private var maxBubbleWidth: CGFloat = UIScreen.main.bounds.width * ChatMessageListConfig.defaultBubbleMaxWidthRatio
    private var baseLayoutKey = ""
    private var streamingMaxCharactersPerSecond: Double = 0
    private var dotsLeadingConstraint: Constraint?

    private let markdownView = StreamingMarkdownView()
    private let loadingDots = StreamingLoadingDotsView()
    private lazy var linkTapGesture: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleLinkTap(_:)))
        gesture.delegate = self
        gesture.cancelsTouchesInView = false
        return gesture
    }()

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        markdownView.onDisplayedHeightChange = { [weak self] in
            self?.refreshTableRowHeight()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - MessageContentView

    func bind(message: MessageInfo, context: MessageContentContext) {
        maxBubbleWidth = UIScreen.main.bounds.width * context.config.bubbleMaxWidthRatio
        streamingMaxCharactersPerSecond = context.config.streamingMaxCharactersPerSecond
        baseLayoutKey = "\(context.isLeft)|\(context.isMultiSelectMode)"
        if let data = ChatbotMessageProtocol.parse(message) {
            bind(
                msgID: message.msgID,
                text: data.displayText,
                isStreaming: data.isPlaceholder || (data.source == .flow && !data.isFinished),
                showLoadingDots: data.isPlaceholder || (data.source == .flow && !data.isFinished),
                textColor: TUIChatKitTheme.colors.textColorPrimary,
                dotColor: TUIChatKitTheme.colors.textColorSecondary
            )
            return
        }
        if case .stream(let payload) = message.messagePayload {
            let isSelf = context.isSelf
            bind(
                msgID: message.msgID,
                text: payload.markdown,
                isStreaming: !payload.isStreamEnded,
                showLoadingDots: false,
                textColor: isSelf ? TUIChatKitTheme.colors.textColorAntiPrimary : TUIChatKitTheme.colors.textColorPrimary,
                dotColor: isSelf ? TUIChatKitTheme.colors.textColorAntiSecondary : TUIChatKitTheme.colors.textColorSecondary
            )
            return
        }
        bind(
            msgID: "",
            text: "",
            isStreaming: false,
            showLoadingDots: false,
            textColor: TUIChatKitTheme.colors.textColorPrimary,
            dotColor: TUIChatKitTheme.colors.textColorSecondary
        )
    }

    // MARK: - Bind

    /// [isStreaming] 只影响 Markdown 渲染：正文还在生成时语法可能是断的（未闭合的代码块、表格），
    /// 需要先做补全处理。[showLoadingDots] 单独控制文末的三点动画，因为 TIMStreamElem
    /// 这条路径要的是「边出字边渲染、但不显示加载点」。
    func bind(msgID: String, text: String, isStreaming: Bool, showLoadingDots: Bool, textColor: UIColor, dotColor: UIColor) {
        loadingDots.setDotColor(dotColor)
        loadingDots.setLoading(showLoadingDots)
        if showLoadingDots {
            dotsLeadingConstraint?.activate()
        } else {
            dotsLeadingConstraint?.deactivate()
        }
        markdownView.bind(
            msgID: msgID,
            markdown: text,
            isStreaming: isStreaming,
            textColor: textColor,
            maxTextWidth: maxTextWidth,
            layoutKey: "\(baseLayoutKey)|\(showLoadingDots)",
            maxCharactersPerSecond: streamingMaxCharactersPerSecond
        )
    }

    func recycle() {
        markdownView.recycle()
        loadingDots.setLoading(false)
    }

    private var maxTextWidth: CGFloat {
        return maxBubbleWidth - Self.horizontalPadding * 2
    }

    private func refreshTableRowHeight() {
        var view = superview
        while let current = view {
            if let tableView = current as? UITableView {
                UIView.performWithoutAnimation {
                    tableView.beginUpdates()
                    tableView.endUpdates()
                }
                NotificationCenter.default.post(name: .messageListStreamingContentDidGrow, object: nil)
                return
            }
            view = current.superview
        }
    }

    // MARK: - Private

    private func constructViewHierarchy() {
        addSubview(markdownView)
        addSubview(loadingDots)
        addGestureRecognizer(linkTapGesture)
    }

    private func activateConstraints() {
        markdownView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(Self.verticalPadding)
            make.leading.equalToSuperview().offset(Self.horizontalPadding)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalPadding)
        }
        loadingDots.snp.makeConstraints { make in
            dotsLeadingConstraint = make.leading.equalTo(markdownView.snp.trailing).offset(Self.dotsSpacing).constraint
            make.bottom.equalToSuperview().offset(-Self.verticalPadding)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalPadding)
            make.size.equalTo(Self.dotsSize)
        }
    }

    private func linkURL(at point: CGPoint) -> URL? {
        return markdownView.linkURL(at: convert(point, to: markdownView))
    }

    @objc private func handleLinkTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        guard let url = linkURL(at: point) else { return }
        UIApplication.shared.open(url)
    }
}

extension MessageStreamingContentView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === linkTapGesture else { return true }
        return linkURL(at: touch.location(in: self)) != nil
    }
}

/// 文末三点加载动画：正弦波透明度依次起伏，对齐 Android StreamingLoadingDotsView。
private final class StreamingLoadingDotsView: UIView {
    private static let dotRadius: CGFloat = 2
    private static let dotSpacing: CGFloat = 7
    private static let waveDuration: TimeInterval = 0.9
    private static let minAlpha: CGFloat = 64.0 / 255.0

    private var phase: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var linkStartTime: CFTimeInterval = 0
    private var dotColor: UIColor = .gray

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setDotColor(_ color: UIColor) {
        dotColor = color
        setNeedsDisplay()
    }

    func setLoading(_ loading: Bool) {
        isHidden = !loading
        if loading {
            startAnimatorIfNeeded()
        } else {
            stopAnimator()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopAnimator()
        } else if !isHidden {
            startAnimatorIfNeeded()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let spacing = Self.dotSpacing
        let totalWidth = spacing * 2
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2
        for index in 0..<3 {
            let wave = (sin((phase - CGFloat(index) / 3.0) * 2 * .pi) + 1) / 2
            let alpha = Self.minAlpha + wave * (1 - Self.minAlpha)
            context.setFillColor(dotColor.withAlphaComponent(alpha).cgColor)
            let rect = CGRect(
                x: startX + spacing * CGFloat(index) - Self.dotRadius,
                y: centerY - Self.dotRadius,
                width: Self.dotRadius * 2,
                height: Self.dotRadius * 2
            )
            context.fillEllipse(in: rect)
        }
    }

    private func startAnimatorIfNeeded() {
        guard displayLink == nil, window != nil else { return }
        linkStartTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopAnimator() {
        displayLink?.invalidate()
        displayLink = nil
        phase = 0
        setNeedsDisplay()
    }

    @objc private func tick(_ link: CADisplayLink) {
        phase = CGFloat((CACurrentMediaTime() - linkStartTime).truncatingRemainder(dividingBy: Self.waveDuration) / Self.waveDuration)
        setNeedsDisplay()
    }
}

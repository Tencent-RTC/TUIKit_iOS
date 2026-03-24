import UIKit
import SnapKit
import Combine
import AtomicXCore

/**
 * Barrage interaction component
 *
 * APIs involved:
 * - BarrageStore.create(liveID:) - create a barrage management instance
 * - BarrageStore.sendTextMessage(text:extensionInfo:completion:) - send a text barrage
 * - BarrageStore.appendLocalTip(message:) - append a local tip message (gift messages, etc.)
 * - BarrageStore.state - barragestate subscription (BarrageState.messageList)
 * - GiftStore.create(liveID:) - create a gift management instance
 * - GiftStore.giftEventPublisher - giftevent subscription (GiftEvent.onReceiveGift)
 *
 * Features:
 * - Display the barrage message list (automatically scroll to the bottom)
 * - Send a text barrage from the bottom input field
 * - Listen for gift events and automatically insert gift messages into the barrage list ("xx sent xx xcount")
 */
class BarrageView: UIView {

    // MARK: - Properties

    private let liveID: String
    private lazy var barrageStore = BarrageStore.create(liveID: liveID)
    private lazy var giftStore = GiftStore.create(liveID: liveID)
    private var cancellables = Set<AnyCancellable>()
    private var messages: [Barrage] = []
    private var overlayInputView: BarrageOverlayInputView?

    // MARK: - UI Components

    /// barrage message list
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.delegate = self
        table.dataSource = self
        table.register(BarrageCell.self, forCellReuseIdentifier: BarrageCell.reuseIdentifier)
        table.allowsSelection = false
        return table
    }()

    /// bottom placeholder input button (tapping it shows the overlay input field)
    private let inputPlaceholder: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        button.layer.cornerRadius = 20
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.setTitle("interactive.barrage.placeholder".localized, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return button
    }()

    // MARK: - Init

    init(liveID: String) {
        self.liveID = liveID
        super.init(frame: .zero)
        setupUI()
        setupBindings()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(tableView)
        addSubview(inputPlaceholder)

        inputPlaceholder.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview()
            make.height.equalTo(40)
        }

        tableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(inputPlaceholder.snp.top).offset(-8)
        }
    }

    private func setupBindings() {
        // Subscribe to barrage message list changes
        barrageStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.messages = state.messageList
                self?.tableView.reloadData()
                self?.scrollToBottom()
            }
            .store(in: &cancellables)

        // Subscribe to gift events, AutomaticallyInsert the gift message into the barrage list
        giftStore.giftEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .onReceiveGift(_, let gift, let count, let sender):
                    self?.insertGiftBarrage(gift: gift, count: count, sender: sender)
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Gift Barrage

    /// Insert the gift message into the barrage list ("xx sent xx xcount")
    private func insertGiftBarrage(gift: Gift, count: UInt8, sender: LiveUserInfo) {
        let senderName = sender.userName.isEmpty ? sender.userID : sender.userName
        var barrage = Barrage()
        barrage.textContent = "\(senderName) \("interactive.gift.sent".localized) \(gift.name) x\(count)"
        barrageStore.appendLocalTip(message: barrage)
    }

    private func setupActions() {
        inputPlaceholder.addTarget(self, action: #selector(showOverlayInput), for: .touchUpInside)
    }

    // MARK: - Overlay Input

    /// Tap the placeholder button → show the overlay input field on the window
    @objc private func showOverlayInput() {
        guard let window = self.window, overlayInputView == nil else { return }

        let overlay = BarrageOverlayInputView()
        overlay.onSend = { [weak self] text in
            self?.sendBarrage(text: text)
        }
        overlay.onDismiss = { [weak self] in
            self?.overlayInputView?.removeFromSuperview()
            self?.overlayInputView = nil
        }
        window.addSubview(overlay)
        overlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        overlayInputView = overlay
        overlay.activate()
    }

    // MARK: - Actions

    /// send a text barrage
    private func sendBarrage(text: String) {
        guard !text.isEmpty else { return }
        barrageStore.sendTextMessage(text: text, extensionInfo: nil) { _ in }
    }

    // MARK: - Helpers

    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension BarrageView: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: BarrageCell.reuseIdentifier, for: indexPath) as? BarrageCell else {
            return UITableViewCell()
        }
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}

// MARK: - BarrageCell

/// Barrage message cell - semi-transparent background displaying the sender nickname and message content
private class BarrageCell: UITableViewCell {

    static let reuseIdentifier = "BarrageCell"

    private let bubbleView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.layer.cornerRadius = 12
        return view
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)

        bubbleView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.equalToSuperview().offset(2)
            make.bottom.equalToSuperview().offset(-2)
            make.trailing.lessThanOrEqualToSuperview().offset(-60)
        }

        messageLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with barrage: Barrage) {
        let senderName = barrage.sender.userName.isEmpty ? barrage.sender.userID : barrage.sender.userName
        let attributed = NSMutableAttributedString()

        // sender name (highlight color)
        let nameAttr = NSAttributedString(
            string: "\(senderName): ",
            attributes: [
                .foregroundColor: UIColor.systemCyan,
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
            ]
        )
        attributed.append(nameAttr)

        // Message content
        let textAttr = NSAttributedString(
            string: barrage.textContent,
            attributes: [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 13)
            ]
        )
        attributed.append(textAttr)

        messageLabel.attributedText = attributed
    }
}

// MARK: - BarrageOverlayInputView

/// Barrage input view overlaid on the window (semi-transparent dimming view + input field above the keyboard)
private class BarrageOverlayInputView: UIView, UITextFieldDelegate {

    var onSend: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private var inputBottomConstraint: Constraint?

    private let dimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        return view
    }()

    private let inputBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.15, alpha: 0.95)
        return view
    }()

    private let textField: UITextField = {
        let field = UITextField()
        field.textColor = .white
        field.font = .systemFont(ofSize: 15)
        field.attributedPlaceholder = NSAttributedString(
            string: "interactive.barrage.placeholder".localized,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
        )
        field.returnKeyType = .send
        field.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        field.layer.cornerRadius = 18
        // left inner padding
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        field.rightViewMode = .always
        return field
    }()

    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "paperplane.fill", withConfiguration: config), for: .normal)
        button.tintColor = .systemBlue
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        addSubview(dimView)
        addSubview(inputBar)
        inputBar.addSubview(textField)
        inputBar.addSubview(sendButton)

        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        inputBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            inputBottomConstraint = make.bottom.equalToSuperview().constraint
            make.height.equalTo(52)
        }

        textField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.height.equalTo(36)
            make.trailing.equalTo(sendButton.snp.leading).offset(-8)
        }

        sendButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.equalTo(44)
        }
    }

    private func setupActions() {
        // Tap the dimming view to dismiss the keyboard → dismiss automatically
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        dimView.addGestureRecognizer(tap)

        sendButton.addTarget(self, action: #selector(handleSend), for: .touchUpInside)
        textField.delegate = self
    }

    /// Activate the keyboard
    func activate() {
        textField.becomeFirstResponder()
    }

    @objc private func handleSend() {
        guard let text = textField.text, !text.isEmpty else { return }
        onSend?(text)
        textField.text = ""
    }

    @objc private func dismiss() {
        textField.resignFirstResponder()
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        handleSend()
        return true
    }

    // MARK: - Keyboard

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }

        let screenHeight = UIScreen.main.bounds.height
        let keyboardTop = endFrame.origin.y
        let offset = max(0, screenHeight - keyboardTop)

        let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 7
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)

        inputBottomConstraint?.update(offset: -offset)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.layoutIfNeeded()
        }

        // When the keyboard is fully dismissed → remove the overlay
        if offset == 0 {
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                self.dimView.alpha = 0
            }) { _ in
                self.onDismiss?()
            }
        }
    }
}

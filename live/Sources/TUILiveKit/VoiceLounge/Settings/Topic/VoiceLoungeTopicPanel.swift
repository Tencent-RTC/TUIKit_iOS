import Foundation
import SnapKit
import UIKit

final class VoiceLoungeTopicPanel: BottomSheetView {
    static let maxLength = 40

    var onConfirm: ((_ topic: String) -> Void)?

    private let inputField = UITextField()
    private let counterLabel = UILabel()
    private let listStack = UIStackView()
    private let scrollView = UIScrollView()
    private let footerLabel = LiveText.voiceLounge(.metadata, tone: .tertiary, alignment: .center)
    private let confirmButton = UIButton(type: .system)

    private let topics = VoiceLoungeTopic.presets
    private var rows: [TopicRow] = []
    private var selectedText: String = ""
    private var skin = VoiceLoungeSkin.defaultSkin

    override var sheetHeight: CGFloat { 560 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    func show(current: String, skin: VoiceLoungeSkin) {
        self.skin = skin
        selectedText = current
        inputField.text = current.isEmpty ? nil : current
        syncSelection()
        syncLimit()
        present()
    }

    private func setupViews() {
        contentView.addSubview(inputField)
        contentView.addSubview(scrollView)
        scrollView.addSubview(listStack)

        for topic in topics {
            let row = TopicRow(topic: topic)
            row.onTap = { [weak self] in self?.selectTopic(topic.text) }
            listStack.addArrangedSubview(row)
            rows.append(row)
        }

        contentView.addSubview(footerLabel)
        contentView.addSubview(confirmButton)
    }

    private func setupConstraints() {
        inputField.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalToSuperview().offset(66)
            make.height.equalTo(50)
        }
        confirmButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(34)
            make.height.equalTo(48)
        }
        footerLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(confirmButton.snp.top).offset(-12)
        }
        scrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalTo(inputField.snp.bottom).offset(16)
            make.bottom.equalTo(footerLabel.snp.top).offset(-12)
        }
        listStack.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
        }
    }

    private func setupStyles() {
        sheetTitle = .title
        inputField.attributedPlaceholder = NSAttributedString(
            string: .placeholder, attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.4)])
        inputField.textColor = .white
        inputField.font = .systemFont(ofSize: 16)
        inputField.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        inputField.layer.cornerRadius = 12
        inputField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        inputField.leftViewMode = .always
        inputField.clearButtonMode = .never
        counterLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        counterLabel.textAlignment = .right
        counterLabel.frame = CGRect(x: 0, y: 0, width: 50, height: 20)
        let counterContainer = UIView(frame: CGRect(x: 0, y: 0, width: 64, height: 20))
        counterContainer.addSubview(counterLabel)
        inputField.rightView = counterContainer
        inputField.rightViewMode = .always
        inputField.layer.borderWidth = 1
        inputField.returnKeyType = .done
        scrollView.showsVerticalScrollIndicator = false
        listStack.axis = .vertical
        listStack.spacing = 10
        footerLabel.text = .footer
        footerLabel.numberOfLines = 2
        confirmButton.setTitle(.confirm, for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        confirmButton.backgroundColor = skin.mid
        confirmButton.layer.cornerRadius = 24
    }

    private func setupBindings() {
        inputField.delegate = self
        inputField.addTarget(self, action: #selector(inputChanged), for: .editingChanged)
        confirmButton.addTarget(self, action: #selector(tapConfirm), for: .touchUpInside)
    }

    private func selectTopic(_ text: String) {
        selectedText = text
        inputField.text = text
        syncSelection()
        syncLimit()
    }

    private func syncSelection() { rows.forEach { $0.setSelected($0.topicText == selectedText, skin: skin) } }

    private var currentTopic: String { (inputField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isOverLimit: Bool { currentTopic.count > Self.maxLength }

    private func syncLimit() {
        let count = currentTopic.count
        let over = isOverLimit
        counterLabel.text = count > 0 ? "\(count)/\(Self.maxLength)" : ""
        counterLabel.textColor = over ? VoiceLoungeColor.rose : UIColor.white.withAlphaComponent(0.4)
        inputField.layer.borderColor = count > 0 ? skin.mid.cgColor : UIColor.clear.cgColor

        footerLabel.text = over ? String(format: .overLimitHint, Self.maxLength) : .footer
        footerLabel.textColor = over ? VoiceLoungeColor.rose : LiveTheme.Color.text(.tertiary)

        confirmButton.isEnabled = !over
        confirmButton.setTitle(over ? .overLimit : .confirm, for: .normal)
        confirmButton.setTitleColor(over ? VoiceLoungeColor.rose.withAlphaComponent(0.6) : .white, for: .normal)
        confirmButton.backgroundColor = over ? VoiceLoungeColor.rose.withAlphaComponent(0.15) : skin.mid
    }
}

extension VoiceLoungeTopicPanel {
    @objc private func inputChanged() {
        selectedText = inputField.text ?? ""
        syncSelection()
        syncLimit()
    }

    @objc private func tapConfirm() {
        guard !isOverLimit else { return }
        onConfirm?(currentTopic)
        dismiss()
    }
}

extension VoiceLoungeTopicPanel: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

private final class TopicRow: UIControl {
    let topicText: String
    var onTap: (() -> Void)?

    private let tagLabel = UILabel()
    private let textLabel = UILabel()
    private let checkIcon = UIImageView()

    init(topic: VoiceLoungeTopic) {
        topicText = topic.text
        super.init(frame: .zero)
        backgroundColor = UIColor.white.withAlphaComponent(0.05)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.clear.cgColor

        tagLabel.text = topic.tag
        tagLabel.font = .systemFont(ofSize: 13, weight: .medium)
        tagLabel.textColor = .white
        tagLabel.textAlignment = .center
        tagLabel.backgroundColor = VoiceLoungeColor.overlayMarked
        tagLabel.layer.cornerRadius = 9
        tagLabel.layer.masksToBounds = true
        tagLabel.isUserInteractionEnabled = false
        addSubview(tagLabel)

        textLabel.text = topic.text
        textLabel.font = .systemFont(ofSize: 15)
        textLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        textLabel.numberOfLines = 1
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.isUserInteractionEnabled = false
        addSubview(textLabel)

        checkIcon.image = TopicRow.checkmark()
        checkIcon.isHidden = true
        checkIcon.isUserInteractionEnabled = false
        addSubview(checkIcon)

        snp.makeConstraints { $0.height.equalTo(56) }
        tagLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.height.equalTo(22)
            make.width.greaterThanOrEqualTo(44)
        }
        tagLabel.setContentHuggingPriority(.required, for: .horizontal)
        tagLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        checkIcon.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(14)
            make.centerY.equalToSuperview()
            make.size.equalTo(18)
        }
        textLabel.snp.makeConstraints { make in
            make.leading.equalTo(tagLabel.snp.trailing).offset(10)
            make.trailing.lessThanOrEqualTo(checkIcon.snp.leading).offset(-10)
            make.centerY.equalToSuperview()
        }

        addTarget(self, action: #selector(tap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSelected(_ selected: Bool, skin: VoiceLoungeSkin) {
        checkIcon.isHidden = !selected
        checkIcon.tintColor = skin.light
        layer.borderColor = selected ? skin.mid.cgColor : UIColor.clear.cgColor
        tagLabel.textColor = .white
    }

    @objc private func tap() { onTap?() }

    static func checkmark() -> UIImage? {
        LiveKitResources.image(named: "livekit_summary_done")?.withRenderingMode(.alwaysTemplate)
    }
}

private extension String {
    static var confirm: String { LiveKitResources.localizedString("tuilivekit.voiceroom.topic.confirm") }
    static var footer: String { LiveKitResources.localizedString("tuilivekit.voiceroom.topic.footer") }
    static var placeholder: String { LiveKitResources.localizedString("tuilivekit.voiceroom.topic.placeholder") }
    static var title: String { LiveKitResources.localizedString("tuilivekit.voiceroom.topic.title") }
    static var overLimit: String { LiveKitResources.localizedString("tuilivekit.voiceroom.topic.over_limit") }
    static var overLimitHint: String { LiveKitResources.localizedString("tuilivekit.voiceroom.topic.over_limit_hint") }
}

struct VoiceLoungeTopic: Equatable {
    let tag: String
    let text: String
}

extension VoiceLoungeTopic {
    static var presets: [VoiceLoungeTopic] {
        ["tea", "icebreak", "awkward", "whatif", "latenight", "happy"].map { id in
            VoiceLoungeTopic(
                tag: LiveKitResources.localizedString("tuilivekit.voiceroom.topic.preset.\(id).tag"),
                text: LiveKitResources.localizedString("tuilivekit.voiceroom.topic.preset.\(id).text"))
        }
    }
}

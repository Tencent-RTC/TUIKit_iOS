import SnapKit
import UIKit

final class CallAccessTapRow: UIView {

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?()
    }
}

final class CallAccessSheet: UIView {

    var onDismiss: (() -> Void)?

    private enum PresentationState {
        case hidden
        case presenting
        case shown
        case dismissing
    }

    private var presentationState: PresentationState = .hidden
    private var animationGeneration = 0
    private var hostHeight: CGFloat = 0

    private let dimMaskView = UIView()
    private let panelView = UIView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let actionButton = UIButton(type: .system)
    private let contentContainer = UIView()
    private var panelBottomConstraint: Constraint?

    init(title: String, actionTitle: String? = nil, isCancelAction: Bool = false, onAction: (() -> Void)? = nil) {
        super.init(frame: .zero)
        setupViews()
        titleLabel.text = title
        if let actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.setTitleColor(isCancelAction ? CallAccessTheme.callRed : CallAccessTheme.brand, for: .normal)
            actionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: isCancelAction ? .regular : .semibold)
            actionButton.isHidden = false
            // 统一抽屉口径：× 与右上动作键互斥，有 action 的抽屉不渲染 ×
            closeButton.isHidden = true
            if let onAction {
                actionButton.addAction(UIAction { _ in onAction() }, for: .touchUpInside)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setAction(title: String, isCancel: Bool) {
        actionButton.setTitle(title, for: .normal)
        actionButton.setTitleColor(isCancel ? CallAccessTheme.callRed : CallAccessTheme.brand, for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 15, weight: isCancel ? .regular : .semibold)
    }

    /// 在 init 之后接线动作键。需要 weak 捕获 sheet 自身的场景必须走这里（init 参数阶段局部变量尚未赋值）
    func setOnAction(_ handler: @escaping () -> Void) {
        actionButton.addAction(UIAction { _ in handler() }, for: .touchUpInside)
    }

    func setContent(_ content: UIView) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        contentContainer.addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func present(in host: UIView) {
        guard presentationState == .hidden || presentationState == .dismissing else { return }
        let stateBefore = presentationState
        presentationState = .presenting
        animationGeneration += 1
        let generation = animationGeneration
        hostHeight = host.bounds.height

        if stateBefore == .hidden {
            host.addSubview(self)
            snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            panelBottomConstraint?.update(offset: hostHeight)
            layoutIfNeeded()
        }
        panelBottomConstraint?.update(offset: 0)
        UIView.animate(withDuration: 0.24, animations: {
            self.dimMaskView.alpha = 1
            self.layoutIfNeeded()
        }, completion: { [weak self] finished in
            guard let self, finished, generation == self.animationGeneration else { return }
            self.presentationState = .shown
        })
    }

    func dismiss() {
        guard presentationState == .shown || presentationState == .presenting else { return }
        presentationState = .dismissing
        animationGeneration += 1
        let generation = animationGeneration

        panelBottomConstraint?.update(offset: hostHeight)
        UIView.animate(withDuration: 0.24, animations: {
            self.dimMaskView.alpha = 0
            self.layoutIfNeeded()
        }, completion: { [weak self] finished in
            guard let self, finished, generation == self.animationGeneration else { return }
            self.presentationState = .hidden
            self.removeFromSuperview()
            self.onDismiss?()
        })
    }

    private func setupViews() {
        dimMaskView.backgroundColor = CallAccessTheme.mask
        dimMaskView.alpha = 0
        dimMaskView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleMaskTap)))
        addSubview(dimMaskView)
        dimMaskView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        panelView.backgroundColor = .white
        panelView.layer.cornerRadius = 18
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.clipsToBounds = true
        addSubview(panelView)
        panelView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.lessThanOrEqualToSuperview().multipliedBy(0.7)
            panelBottomConstraint = make.bottom.equalToSuperview().offset(0).constraint
        }

        let titleBar = UIView()
        titleBar.layer.borderWidth = CallAccessTheme.hairline
        titleBar.layer.borderColor = CallAccessTheme.line.cgColor
        panelView.addSubview(titleBar)
        titleBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(52)
        }

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = CallAccessTheme.text
        titleBar.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        closeButton.setTitle("×", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 14)
        closeButton.setTitleColor(CallAccessTheme.text2, for: .normal)
        closeButton.backgroundColor = CallAccessTheme.closeBackground
        closeButton.layer.cornerRadius = 13
        closeButton.addTarget(self, action: #selector(handleCloseTap), for: .touchUpInside)
        titleBar.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(26)
        }

        actionButton.isHidden = true
        titleBar.addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }

        panelView.addSubview(contentContainer)
        contentContainer.snp.makeConstraints { make in
            // .sheet-body: padding-top 4; panel padding 0 16 20
            make.top.equalTo(titleBar.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(panelView.safeAreaLayoutGuide).offset(-20)
        }
    }

    /// Updates the title bar text (used when a sheet swaps its content, e.g. language picker).
    func setTitle(_ title: String) {
        titleLabel.text = title
    }

    @objc private func handleMaskTap() {
        dismiss()
    }

    @objc private func handleCloseTap() {
        dismiss()
    }
}

enum CallAccessRowFactory {
    static func optionRow(title: String, isSelected: Bool, showsSeparator: Bool = true, onTap: @escaping () -> Void) -> UIControl {
        let control = UIControl()
        control.backgroundColor = .clear

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: isSelected ? .semibold : .regular)
        label.textColor = isSelected ? CallAccessTheme.brand : CallAccessTheme.text

        let check = UILabel()
        check.text = "✓"
        check.font = .systemFont(ofSize: 15, weight: .bold)
        check.textColor = CallAccessTheme.brand
        check.isHidden = !isSelected

        let separator = UIView()
        separator.backgroundColor = CallAccessTheme.line
        separator.isHidden = !showsSeparator

        control.addSubview(label)
        control.addSubview(check)
        control.addSubview(separator)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(check.snp.leading).offset(-8)
        }
        check.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        separator.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(CallAccessTheme.hairline)
        }
        control.snp.makeConstraints { make in
            make.height.equalTo(52)
        }
        control.addAction(UIAction { _ in onTap() }, for: .touchUpInside)
        return control
    }

    static func toggle(isOn: Bool, onChange: @escaping (Bool) -> Void) -> CallAccessToggle {
        let toggle = CallAccessToggle()
        toggle.isOn = isOn
        toggle.onChange = onChange
        return toggle
    }
}

final class CallAccessToggle: UIControl {

    enum Style {
        case settings
        case caption
    }

    var onChange: ((Bool) -> Void)?

    var isOn: Bool = false {
        didSet { applyState(animated: true) }
    }

    private let style: Style
    private let knob = UIView()

    init(style: Style = .settings) {
        self.style = style
        super.init(frame: .zero)
        setupView()
    }

    override init(frame: CGRect) {
        self.style = .settings
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        layer.cornerRadius = 14

        knob.backgroundColor = .white
        knob.layer.cornerRadius = 12
        knob.layer.shadowColor = UIColor.black.cgColor
        knob.layer.shadowOpacity = 0.16
        knob.layer.shadowOffset = CGSize(width: 0, height: 1)
        knob.layer.shadowRadius = 3
        knob.isUserInteractionEnabled = false
        addSubview(knob)

        snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 46, height: 28))
        }
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        applyState(animated: false)
    }

    private func applyState(animated: Bool) {
        switch style {
        case .settings:
            backgroundColor = isOn ? CallAccessTheme.green : CallAccessTheme.switchOff
        case .caption:
            backgroundColor = isOn ? CallAccessTheme.brand : UIColor(hex: 0xC9CDD4)
        }
        let targetX: CGFloat = isOn ? 20 : 2
        let updates = {
            self.knob.frame = CGRect(x: targetX, y: 2, width: 24, height: 24)
        }
        if animated {
            UIView.animate(withDuration: 0.18, animations: updates)
        } else {
            updates()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if knob.frame.width != 24 {
            knob.frame = CGRect(x: isOn ? 20 : 2, y: 2, width: 24, height: 24)
        }
    }

    @objc private func handleTap() {
        isOn.toggle()
        onChange?(isOn)
    }
}

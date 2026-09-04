import UIKit
import SnapKit

public typealias SearchResultHandler = (Any) -> Void

final class SearchStatusView: UIView {
    private static let horizontalMargin: CGFloat = CGFloat(SpacingScheme.normalSpacing)

    private static let emptyIconSize: CGFloat = 64

    private static let emptyStackSpacing: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private static let defaultKeyboardAnimationDuration: TimeInterval = 0.25

    enum Status {
        case hidden
        case loading
        case empty
    }

    private let indicator = UIActivityIndicatorView(style: .medium)

    private let iconView = UIImageView()

    private let messageLabel = UILabel()

    private let emptyStack = UIStackView()

    private var indicatorCenterYConstraint: Constraint?

    private var emptyStackCenterYConstraint: Constraint?

    init() {
        super.init(frame: .zero)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        observeKeyboard()
        setStatus(.hidden)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setStatus(_ status: Status) {
        switch status {
        case .hidden:
            isHidden = true
            indicator.stopAnimating()
            emptyStack.isHidden = true
        case .loading:
            isHidden = false
            indicator.startAnimating()
            emptyStack.isHidden = true
        case .empty:
            isHidden = false
            indicator.stopAnimating()
            emptyStack.isHidden = false
        }
    }

    private func constructViewHierarchy() {
        addSubview(indicator)
        emptyStack.addArrangedSubview(iconView)
        emptyStack.addArrangedSubview(messageLabel)
        addSubview(emptyStack)
    }

    private func activateConstraints() {
        indicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            self.indicatorCenterYConstraint = make.centerY.equalToSuperview().constraint
        }
        emptyStack.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            self.emptyStackCenterYConstraint = make.centerY.equalToSuperview().constraint
            make.leading.greaterThanOrEqualToSuperview().offset(Self.horizontalMargin)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.horizontalMargin)
        }
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(Self.emptyIconSize)
        }
    }

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleKeyboardChange(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleKeyboardChange(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func handleKeyboardChange(_ notification: Notification) {
        let isHide = notification.name == UIResponder.keyboardWillHideNotification
        var keyboardHeight: CGFloat = 0
        if !isHide,
           let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardFrame = convert(frame.cgRectValue, from: nil)
            keyboardHeight = max(0, bounds.maxY - keyboardFrame.minY)
        }
        let offset = -keyboardHeight / 2
        indicatorCenterYConstraint?.update(offset: offset)
        emptyStackCenterYConstraint?.update(offset: offset)
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? Self.defaultKeyboardAnimationDuration
        UIView.animate(withDuration: duration) { self.layoutIfNeeded() }
    }

    private func setupViewStyle() {
        let colors = TUIChatKitTheme.colors
        indicator.color = colors.textColorSecondary
        indicator.hidesWhenStopped = true

        emptyStack.axis = .vertical
        emptyStack.alignment = .center
        emptyStack.spacing = Self.emptyStackSpacing

        iconView.image = UIImage(systemName: "magnifyingglass")
        iconView.tintColor = colors.textColorSecondary
        iconView.contentMode = .scaleAspectFit

        messageLabel.text = LocalizedChatString("SearchNoResultInConversation")
        messageLabel.font = FontScheme.caption1Regular
        messageLabel.textColor = colors.textColorSecondary
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
    }
}

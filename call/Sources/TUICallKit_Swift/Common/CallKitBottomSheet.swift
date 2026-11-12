import SnapKit
import UIKit

final class CallKitBottomSheet: UIView {

    enum Style {
        case generic
        case callPanel

        var panelBackgroundColor: UIColor {
            switch self {
            case .generic: return .white
            case .callPanel: return CallKitTheme.panelBackground
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .generic: return 18
            case .callPanel: return 20
            }
        }
    }

    var onDismiss: (() -> Void)?

    let panel = UIView()

    private let dimView = UIControl()
    private var panelBottom: Constraint?
    private var isDismissing = false

    init(style: Style = .generic) {
        super.init(frame: .zero)
        backgroundColor = .clear

        dimView.backgroundColor = CallKitTheme.dimBackground
        dimView.addTarget(self, action: #selector(handleMaskTap), for: .touchUpInside)
        addSubview(dimView)
        dimView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        panel.backgroundColor = style.panelBackgroundColor
        panel.layer.cornerRadius = style.cornerRadius
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.clipsToBounds = true
        addSubview(panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(in host: UIView, content: UIView) {
        host.addSubview(self)
        snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        panel.addSubview(content)
        content.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        panel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.lessThanOrEqualTo(host.snp.height).multipliedBy(0.7)
            panelBottom = make.bottom.equalToSuperview().offset(host.bounds.height).constraint
        }
        host.layoutIfNeeded()

        dimView.alpha = 0
        panelBottom?.update(offset: 0)
        UIView.animate(withDuration: 0.24, delay: 0, options: .curveEaseOut) {
            self.dimView.alpha = 1
            host.layoutIfNeeded()
        }
    }

    func dismiss() {
        guard superview != nil, !isDismissing else { return }
        isDismissing = true
        dimView.isEnabled = false
        panelBottom?.update(offset: bounds.height)
        UIView.animate(withDuration: 0.24, delay: 0, options: .curveEaseIn) {
            self.dimView.alpha = 0
            self.superview?.layoutIfNeeded()
        } completion: { _ in
            self.removeFromSuperview()
            self.onDismiss?()
            self.onDismiss = nil
        }
    }

    @objc private func handleMaskTap() {
        dismiss()
    }
}

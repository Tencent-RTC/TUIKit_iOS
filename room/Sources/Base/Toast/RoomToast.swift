import UIKit

public enum RoomToast {

    public static let defaultDuration: TimeInterval = 2
    private static let animationDuration: TimeInterval = 0.25
    fileprivate static let textMaxWidth: CGFloat = 260
    private static var current: ToastLayer?
    private static var dismissWorkItem: DispatchWorkItem?

    public static func show(_ text: String, duration: TimeInterval = defaultDuration) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { show(text, duration: duration) }
            return
        }
        guard let window = keyWindow() else { return }
        dismissCurrent()

        let layerView = ToastLayer(text: text, maxWidth: window.bounds.width - 48)
        current = layerView
        layerView.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(layerView)
        NSLayoutConstraint.activate([
            layerView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            layerView.centerYAnchor.constraint(equalTo: window.centerYAnchor),
        ])

        layerView.alpha = 0
        layerView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseOut) {
            layerView.alpha = 1
            layerView.transform = .identity
        }

        let workItem = DispatchWorkItem {
            guard Self.current === layerView else { return }
            UIView.animate(
                withDuration: Self.animationDuration,
                delay: 0,
                options: .curveEaseIn,
                animations: {
                    layerView.alpha = 0
                    layerView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
                },
                completion: { _ in
                    layerView.removeFromSuperview()
                    if Self.current === layerView {
                        Self.current = nil
                    }
                }
            )
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    public static func dismiss() {
        dismissCurrent()
    }

    private static func dismissCurrent() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        guard let layerView = current else { return }
        layerView.removeFromSuperview()
        current = nil
    }

    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        return windows.first { $0.isKeyWindow } ?? windows.first
    }
}

private final class ToastLayer: UIView {

    init(text: String, maxWidth: CGFloat) {
        super.init(frame: .zero)

        backgroundColor = .roomKitToastBg
        layer.cornerRadius = 8
        isUserInteractionEnabled = false

        let label = UILabel()
        label.numberOfLines = 2
        label.preferredMaxLayoutWidth = min(RoomToast.textMaxWidth, maxWidth - 32)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .roomKitFgOnAccent
        label.textAlignment = .center
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

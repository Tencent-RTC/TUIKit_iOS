import UIKit

/// Lightweight toast for the access app: dark pill near the bottom, auto-dismisses.
enum CallAccessToast {

    static func show(_ text: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async {
            guard let window = activeWindow() else { return }
            container(in: window).show(text: text, duration: duration)
        }
    }

    private final class ToastContainer {
        private weak var window: UIWindow?
        private var currentToast: UIView?
        private var workItem: DispatchWorkItem?

        init(window: UIWindow) {
            self.window = window
        }

        func show(text: String, duration: TimeInterval) {
            workItem?.cancel()
            currentToast?.removeFromSuperview()
            guard let window else { return }

            let toast = makeToast(text: text)
            window.addSubview(toast)
            toast.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                // .toast: centered in the viewport, 0.22s fade + slide up
                toast.centerYAnchor.constraint(equalTo: window.centerYAnchor),
                toast.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, constant: -64),
            ])
            toast.alpha = 0
            toast.transform = CGAffineTransform(translationX: 0, y: 8)
            UIView.animate(withDuration: 0.22) {
                toast.alpha = 1
                toast.transform = .identity
            }
            currentToast = toast

            let item = DispatchWorkItem { [weak self, weak toast] in
                UIView.animate(withDuration: 0.22, animations: {
                    toast?.alpha = 0
                    toast?.transform = CGAffineTransform(translationX: 0, y: 8)
                }, completion: { _ in
                    toast?.removeFromSuperview()
                })
                self?.currentToast = nil
            }
            workItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
        }

        private func makeToast(text: String) -> UIView {
            let container = UIView()
            // .toast: rgba(20,22,28,.88), radius 10, padding 10/16
            container.backgroundColor = UIColor(red: 20 / 255, green: 22 / 255, blue: 28 / 255, alpha: 0.88)
            container.layer.cornerRadius = 10
            let label = UILabel()
            label.text = text
            label.textColor = .white
            label.font = .systemFont(ofSize: 13)
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            ])
            return container
        }
    }

    private static var containers: [ObjectIdentifier: ToastContainer] = [:]

    private static func container(in window: UIWindow) -> ToastContainer {
        let key = ObjectIdentifier(window)
        if let existing = containers[key] { return existing }
        let created = ToastContainer(window: window)
        containers[key] = created
        return created
    }

    private static func activeWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first
    }
}

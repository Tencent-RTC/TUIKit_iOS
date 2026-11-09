import UIKit

// The shell only uses the original text-only, centered toast.
extension UIView {
    func showAtomicToast(text: String) {
        guard !text.isEmpty else { return }
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 3
        label.textAlignment = .center
        let container = UIView()
        container.backgroundColor = UIColor(white: 0.16, alpha: 0.96)
        container.layer.cornerRadius = 6
        label.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.centerYAnchor.constraint(equalTo: centerYAnchor),
            container.widthAnchor.constraint(lessThanOrEqualToConstant: 340),
            container.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])
        container.alpha = 0
        UIView.animate(withDuration: 0.3) { container.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            UIView.animate(withDuration: 0.2, animations: { container.alpha = 0 }) { _ in container.removeFromSuperview() }
        }
    }
}

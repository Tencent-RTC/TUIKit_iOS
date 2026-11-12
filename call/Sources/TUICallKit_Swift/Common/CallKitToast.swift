import SnapKit
import UIKit

enum CallKitToast {

    private static let dismissDelay: TimeInterval = 1.8
    private static weak var currentToast: UIView?

    static func show(_ text: String) {
        guard let host = hostView(), !text.isEmpty else { return }
        currentToast?.removeFromSuperview()

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.textColor = .white

        let toast = UIView()
        toast.backgroundColor = CallKitTheme.toastBackground
        toast.layer.cornerRadius = 10
        toast.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
        }

        host.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        toast.alpha = 0
        UIView.animate(withDuration: 0.2) { toast.alpha = 1 }
        currentToast = toast

        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) { [weak toast] in
            guard let toast else { return }
            UIView.animate(withDuration: 0.2, animations: { toast.alpha = 0 }) { _ in
                toast.removeFromSuperview()
            }
        }
    }

    private static func hostView() -> UIView? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        for scene in scenes {
            if let window = scene.windows.last(where: { !$0.isHidden }) {
                return window
            }
        }
        return nil
    }
}

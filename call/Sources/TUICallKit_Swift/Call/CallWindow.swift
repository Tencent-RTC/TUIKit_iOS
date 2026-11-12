import SnapKit
import UIKit

final class CallWindow {

    private var window: UIWindow?
    private var bannerWindow: UIWindow?
    private var bannerView: IncomingBannerView?

    var isShowing: Bool {
        window?.isHidden == false
    }

    var isBannerShowing: Bool {
        bannerWindow?.isHidden == false
    }

    func showFullScreen(_ controller: UIViewController) {
        if window == nil {
            window = makeWindow(background: CallKitTheme.audioBackgroundBottom)
        }
        window?.rootViewController = controller
        window?.isHidden = false
    }

    func showBanner(_ banner: IncomingBannerView) {
        if bannerWindow == nil {
            let window = makeWindow(background: .clear)
            window.rootViewController = BannerHostViewController()
            bannerWindow = window
        }
        guard let host = bannerWindow?.rootViewController?.view as? BannerPassthroughView else { return }
        bannerView?.removeFromSuperview()
        bannerView = banner
        host.touchable = banner
        host.addSubview(banner)
        banner.snp.makeConstraints { make in
            make.top.equalTo(host.safeAreaLayoutGuide.snp.top).offset(8)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(72)
        }
        bannerWindow?.isHidden = false

        banner.transform = CGAffineTransform(translationX: 0, y: -120)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            banner.transform = .identity
        }
    }

    func dismissBanner() {
        guard let bannerWindow, bannerWindow.isHidden == false else { return }
        let banner = bannerView
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            banner?.transform = CGAffineTransform(translationX: 0, y: -120)
        } completion: { _ in
            bannerWindow.isHidden = true
            bannerWindow.rootViewController = nil
            banner?.removeFromSuperview()
        }
        self.bannerWindow = nil
        bannerView = nil
    }

    func dismiss() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }

    private func makeWindow(background: UIColor?) -> UIWindow {
        let window = activeWindowScene().map(UIWindow.init(windowScene:)) ?? UIWindow(frame: UIScreen.main.bounds)
        window.windowLevel = .alert + 1
        window.backgroundColor = background
        return window
    }

    private func activeWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}

private final class BannerPassthroughView: UIView {

    weak var touchable: UIView?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let touchable else { return false }
        return touchable.point(inside: convert(point, to: touchable), with: event)
    }
}

private final class BannerHostViewController: UIViewController {

    override func loadView() {
        view = BannerPassthroughView()
    }
}

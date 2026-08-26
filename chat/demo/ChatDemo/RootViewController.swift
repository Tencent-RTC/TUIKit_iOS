import AtomicXCore
import ChatUIKit
import Combine
import UIKit

final class DemoLanguageManager {
    static let shared = DemoLanguageManager()

    static let languageDidChangeNotification = Notification.Name("DemoLanguageDidChangeNotification")

    private(set) var currentLanguage: String

    let supportedLanguages: [(code: String, nativeName: String)] = [
        ("en", "English"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("ar", "العربية")
    ]

    var isRTL: Bool {
        ["ar", "he", "fa", "ur"].contains(currentLanguage)
    }

    func setLanguage(_ code: String) {
        guard code != currentLanguage else { return }
        currentLanguage = code
        LanguageHelper.saveLanguage(code)
        NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)
    }

    func currentLanguageName() -> String {
        supportedLanguages.first(where: { $0.code == currentLanguage })?.nativeName ?? "English"
    }

    private init() {
        currentLanguage = LanguageHelper.getCurrentLanguage()
    }
}

final class RootViewController: UIViewController {
    private var currentChild: UIViewController?

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChatUIKitTheme.colors.bgColorOperate
        applyLayoutDirection()
        bindLoginStatus()
        bindLanguageChange()
        bindPrimaryColorChange()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyLayoutDirection()
    }

    private func bindLoginStatus() {
        let initial = LoginStore.shared.state.value.loginStatus
        switchRoot(for: initial)
        LoginStore.shared.state
            .subscribe(StatePublisherSelector(keyPath: \LoginState.loginStatus))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.switchRoot(for: status)
            }
            .store(in: &cancellables)
    }

    private func bindLanguageChange() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageDidChange),
            name: DemoLanguageManager.languageDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoLoginDidFail),
            name: AutoLoginViewController.didFailNotification,
            object: nil
        )
    }

    @objc private func handleAutoLoginDidFail() {
        switchTo(LocalLoginViewController())
    }

    @objc private func handleLanguageDidChange() {
        applyLayoutDirection()
        guard currentChild is HomeTabBarController else {
            if currentChild is LocalLoginViewController {
                switchTo(LocalLoginViewController(), rebuild: true)
            }
            return
        }
        switchTo(HomeTabBarController(), rebuild: true)
    }

    private func bindPrimaryColorChange() {
        ThemeState.shared.$currentTheme
            .map(\.primaryColor)
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildCurrentChild()
            }
            .store(in: &cancellables)
    }

    private func rebuildCurrentChild() {
        if currentChild is HomeTabBarController {
            switchTo(HomeTabBarController(), rebuild: true)
        } else if currentChild is LocalLoginViewController {
            switchTo(LocalLoginViewController(), rebuild: true)
        }
    }

    private func applyLayoutDirection() {
        let attribute: UISemanticContentAttribute = DemoLanguageManager.shared.isRTL ? .forceRightToLeft : .forceLeftToRight
        view.window?.semanticContentAttribute = attribute
        view.semanticContentAttribute = attribute
    }

    private func switchRoot(for status: LoginStatus) {
        switch status {
        case .logined:
            if !(currentChild is HomeTabBarController) {
                switchTo(HomeTabBarController())
            }
        case .unlogin:
            if currentChild is AutoLoginViewController {
                return
            }
            if AutoLoginViewController.hasSavedCredentials {
                switchTo(AutoLoginViewController())
            } else if !(currentChild is LocalLoginViewController) {
                switchTo(LocalLoginViewController())
            }
        }
    }

    private func switchTo(_ viewController: UIViewController, rebuild: Bool = false) {
        if !rebuild, type(of: viewController) == type(of: currentChild ?? UIViewController()) {
            return
        }
        let previous = currentChild
        addChild(viewController)
        viewController.view.frame = view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(viewController.view)
        viewController.didMove(toParent: self)
        currentChild = viewController
        if let previous = previous {
            previous.willMove(toParent: nil)
            previous.view.removeFromSuperview()
            previous.removeFromParent()
        }
    }
}

import UIKit
import Network
import TCMediaX

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var coordinator: LiveKitAccessCoordinator?
    private let effectLicenseMonitor = NWPathMonitor()
    private let effectLicenseQueue = DispatchQueue(label: "com.tencent.tuilivekit.effect-license")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        startEffectLicenseAuthorization()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .black
        let coordinator = LiveKitAccessCoordinator(window: window)
        self.coordinator = coordinator
        coordinator.start()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    private func startEffectLicenseAuthorization() {
        effectLicenseMonitor.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            DispatchQueue.main.async {
                TCMediaXBase.getInstance().setLicenceURL(
                    GenerateTestUserSig.TENCENT_EFFECT_LICENSE_URL,
                    key: GenerateTestUserSig.TENCENT_EFFECT_LICENSE_KEY
                )
            }
        }
        effectLicenseMonitor.start(queue: effectLicenseQueue)
    }
}

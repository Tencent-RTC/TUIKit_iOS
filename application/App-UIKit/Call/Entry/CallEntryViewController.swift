import AtomicXCore
import TUICallKit_Swift
import UIKit

/// G1 entry page after login: the callee-ID form + "start call" CTA.
final class CallEntryViewController: UIViewController {

    private let entryView = CallEntryView()
    private let state = CallEntryState.shared
    private var isCalling = false

    // Sheets hold their own subscriptions and actions; keep them alive until dismissed.
    private var friendPicker: FriendPickerSheet?

    override func loadView() {
        view = entryView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = CallAccessText.entryTitle
        configureNavigationBar()
        bindActions()
        applyFacadeSettings()
    }

    /// Re-applies switch-style settings to the facade so they match the restored local state.
    private func applyFacadeSettings() {
        let facade = TUICallKit.createInstance()
        facade.enableMuteMode(enable: state.muteModeEnabled)
        facade.enableIncomingBanner(enable: state.bannerOn)
        facade.enableFloatWindow(enable: state.showFloatButton)
        facade.enableVirtualBackground(enable: state.blurBackgroundOn)
        facade.enableAITranscriber(enable: state.captionOn)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        entryView.reloadFromState()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .darkContent
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var shouldAutorotate: Bool { false }

    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = CallAccessTheme.pageBackground
        appearance.shadowColor = nil
        appearance.titleTextAttributes = [
            // .nav-title: 17px / 600 / #181A1C (one shade darker than --text, from theme.css)
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor(hex: 0x181A1C),
        ]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        let backItem = UIBarButtonItem(
            image: UIImage(named: "callkit_icon_back")?.withRenderingMode(.alwaysTemplate),
            style: .plain,
            target: self,
            action: #selector(handleBackTap)
        )
        backItem.tintColor = CallAccessTheme.brand
        navigationItem.leftBarButtonItem = backItem
        // Pushed pages (G2) show a chevron-only back button, matching the demo's `.nav-btn`.
        navigationItem.backButtonDisplayMode = .minimal
    }

    @objc private func handleBackTap() {
        navigationController?.popViewController(animated: true)
    }

    private func bindActions() {
        entryView.onFriendsTap = { [weak self] in
            self?.openFriendPicker()
        }
        entryView.onMoreSettingsTap = { [weak self] in
            self?.navigationController?.pushViewController(CallSettingsViewController(), animated: true)
        }
        entryView.onStartCallTap = { [weak self] in
            self?.startCall()
        }
    }

    private func openFriendPicker() {
        guard let host = navigationController?.view ?? view else { return }
        entryView.commitPendingInput(isForCall: false)
        let picker = FriendPickerSheet()
        friendPicker = picker
        picker.present(in: host) { [weak self] in
            self?.entryView.reloadFromState()
            self?.friendPicker = nil
        }
    }

    /// "Start call": parse IDs, apply quality, then call through the public facade.
    /// The in-call UI ships in a later phase; here we only drive the signaling layer.
    private func startCall() {
        guard !isCalling else { return }
        guard entryView.commitPendingInput(isForCall: true) else { return }

        let calleeIDs = state.userIDs.filter { $0 != LoginStore.shared.state.value.loginUserInfo?.userID }
        guard !calleeIDs.isEmpty else {
            CallAccessToast.show(state.userIDs.isEmpty ? CallAccessText.callEmptyCallee : CallAccessText.callSelfOnly)
            return
        }

        if state.media == .video {
            guard let quality = state.resolution.videoQuality else {
                CallAccessToast.show(CallAccessText.quality2KUnsupported)
                return
            }
            DeviceStore.shared.updateVideoQuality(quality, orientation: .portrait)
        }

        var params = CallParams()
        params.roomId = state.roomID
        params.timeout = state.timeoutSeconds
        params.userData = state.extendedInfo

        isCalling = true
        entryView.setCallButtonEnabled(false)
        let mediaType: CallMediaType = state.media == .video ? .video : .audio
        TUICallKit.createInstance().calls(userIdList: calleeIDs, mediaType: mediaType, params: params) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isCalling = false
                self.entryView.setCallButtonEnabled(true)
                switch result {
                case .success:
                    CallAccessToast.show(CallAccessText.callCalling)
                case .failure(let error):
                    CallAccessToast.show(String(format: CallAccessText.callFailed, "\(error.code) \(error.message)"))
                }
            }
        }
    }
}

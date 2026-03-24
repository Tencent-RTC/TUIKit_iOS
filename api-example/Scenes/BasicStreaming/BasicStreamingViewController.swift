import UIKit
import SnapKit
import Combine
import Toast_Swift
import AtomicXCore

/**
 * Business scenario: basic push/pull streaming page
 *
 * APIs involved:
 * - LiveListStore.shared.createLive(_:completion:) - Hostcreate a live stream
 * - LiveListStore.shared.joinLive(liveID:completion:) - Audiencejoin the live stream
 * - LiveListStore.shared.endLive(completion:) - Hostend the live stream
 * - LiveListStore.shared.leaveLive(completion:) - Audienceleave the live stream
 * - LiveListStore.shared.liveListEventPublisher - live event observation (LiveListEvent)
 * - DeviceStore.shared.openLocalCamera(isFront:completion:) - open the camera
 * - DeviceStore.shared.openLocalMicrophone(completion:) - open the microphone
 * - DeviceStore.shared.closeLocalCamera() - close the camera
 * - DeviceStore.shared.closeLocalMicrophone() - close the microphone
 * - LiveCoreView(viewType:) - video rendering component (pushView /playView)
 *
 * Different operations are provided based on the user role:
 * - host: enter the page → open the camera/microphone → tap "Start Live" → show the "End Live" button in the navigation bar during the live session
 * - audience: enter the page → automatically join the room → navigate back if joining fails → display the play stream view on success → leave via the navigation bar back action
 */
class BasicStreamingViewController: UIViewController {

    // MARK: - Properties

    let role: Role
    let liveID: String

    /// Whether the live session is currently active
    private var isLiveActive: Bool = false

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(role: Role, liveID: String) {
        self.role = role
        self.liveID = liveID
        super.init(nibName: nil, bundle: nil)
        // Hide the bottom tab bar
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Components

    /// Video rendering area - the host uses `pushView`, and the audience uses `playView` (full-screen)
    private lazy var liveCoreView: LiveCoreView = {
        let viewType: AtomicXCore.CoreViewType = (role == .anchor) ? .pushView : .playView
        let view = LiveCoreView(viewType: viewType)
        view.setLiveID(liveID)
        view.backgroundColor = .black
        return view
    }()

    /// "Start Live" button (used only by the host, centered)
    private lazy var startLiveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("basicStreaming.startLive".localized, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.snp.makeConstraints { make in
            make.width.equalTo(200)
            make.height.equalTo(50)
        }
        button.addTarget(self, action: #selector(startLiveButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTransparentNavigationBar()
        setupBindings()
        configureForRole()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Disable the interactive pop gesture
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Restore the interactive pop gesture
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true

        // Make sure live-stream resources are cleaned up before the page disappears
        if isMovingFromParent {
            cleanupLiveSession()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .black

        // Full-screen video rendering area
        view.addSubview(liveCoreView)
        liveCoreView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupTransparentNavigationBar() {
        // Use the room ID as the navigation title
        navigationItem.title = liveID

        // Transparent navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance

        // Back button color
        navigationController?.navigationBar.tintColor = .white
    }

    private func setupBindings() {
        // Observe live-stream events such as stream end and forced removal
        LiveListStore.shared.liveListEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleLiveListEvent(event)
            }
            .store(in: &cancellables)
    }

    /// Configure different interaction logic based on the user role
    private func configureForRole() {
        switch role {
        case .anchor:
            configureForAnchor()
        case .audience:
            configureForAudience()
        }
    }

    // MARK: - Host Configuration

    private func configureForAnchor() {
        // Configure a custom back button (the host can go back before the stream starts)
        setupAnchorBackButton()

        // Configure the device management button on the right side of the navigation bar
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        navigationItem.rightBarButtonItem = settingsButton

        // Enable the camera and microphone by default
        DeviceStore.shared.openLocalCamera(isFront: true, completion: nil)
        DeviceStore.shared.openLocalMicrophone(completion: nil)

        // Display the centered "Start Live" button
        view.addSubview(startLiveButton)
        startLiveButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-100)
        }
    }

    private func setupAnchorBackButton() {
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(anchorBackTapped)
        )
        navigationItem.leftBarButtonItem = backButton
    }

    // MARK: - Audience Configuration

    private func configureForAudience() {
        // Configure the back button (leaving the room API is called when the audience taps Back)
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(audienceBackTapped)
        )
        navigationItem.leftBarButtonItem = backButton

        // Audience users do not have device control buttons
        navigationItem.rightBarButtonItem = nil

        // Automatically join the room after entering
        joinLive()
    }

    // MARK: - Actions

    /// Host back button tapped
    @objc private func anchorBackTapped() {
        if isLiveActive {
            // If the live session is active, end it before navigating back
            endLiveAndGoBack()
        } else {
            // If the stream has not started yet, close the devices and navigate back
            DeviceStore.shared.closeLocalCamera()
            DeviceStore.shared.closeLocalMicrophone()
            navigationController?.popViewController(animated: true)
        }
    }

    /// Audience back button tapped
    @objc private func audienceBackTapped() {
        if isLiveActive {
            leaveLiveAndGoBack()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    /// Open the device management panel
    @objc private func settingsTapped() {
        let deviceSettingView = DeviceSettingView()
        let panel = SettingPanelController(
            title: "deviceSetting.title".localized,
            contentView: deviceSettingView
        )
        panel.show(in: self)
    }

    /// Start Live button tapped
    @objc private func startLiveButtonTapped() {
        createLive()
    }

    // MARK: - Host: Create Live Stream

    private func createLive() {
        view.makeToast("basicStreaming.status.creating".localized)
        startLiveButton.isEnabled = false

        var liveInfo = LiveInfo(seatTemplate: .videoDynamicGrid9Seats)
        liveInfo.liveID = liveID
        LiveListStore.shared.createLive(liveInfo) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let createdLiveInfo):
                    self.isLiveActive = true

                    // Set the LiveID on LiveCoreView to start rendering the host stream
                    self.liveCoreView.setLiveID(createdLiveInfo.liveID)

                    // Hide the "Start Live" button
                    self.startLiveButton.isHidden = true

                    // Replace the right navigation bar item with the "End Live" button
                    self.updateNavigationBarForLiveState()

                    self.view.makeToast(String(format: "basicStreaming.status.created".localized, createdLiveInfo.liveID))

                case .failure(let error):
                    self.startLiveButton.isEnabled = true
                    self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))

                    // If creation fails, close any devices that were already opened
                    DeviceStore.shared.closeLocalCamera()
                    DeviceStore.shared.closeLocalMicrophone()
                }
            }
        }
    }

    // MARK: - Audience: Join Live Stream

    private func joinLive() {
        view.makeToast("basicStreaming.status.joining".localized)

        LiveListStore.shared.joinLive(liveID: liveID) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let liveInfo):
                    self.isLiveActive = true
                    self.liveCoreView.setLiveID(liveInfo.liveID)
                    self.view.makeToast(String(format: "basicStreaming.status.joined".localized, liveInfo.liveID))

                case .failure(let error):
                    // If joining fails, navigate back to the previous screen
                    self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message)) { _ in
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            }
        }
    }

    // MARK: - Host: End Live Stream and Go Back

    private func endLiveAndGoBack() {
        view.makeToast("basicStreaming.status.ending".localized)

        LiveListStore.shared.endLive { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    DeviceStore.shared.closeLocalCamera()
                    DeviceStore.shared.closeLocalMicrophone()
                    self.isLiveActive = false
                    self.navigationController?.popViewController(animated: true)

                case .failure(let error):
                    self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    /// Host: end the live stream only (used for passive termination scenarios without leaving the page)
    private func endLive() {
        guard isLiveActive else { return }

        LiveListStore.shared.endLive { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    DeviceStore.shared.closeLocalCamera()
                    DeviceStore.shared.closeLocalMicrophone()
                    self.isLiveActive = false
                    self.view.makeToast("basicStreaming.status.ended".localized)
                    self.resetToPreLiveState()

                case .failure(let error):
                    self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    // MARK: - Audience: Leave Live Stream and Go Back

    private func leaveLiveAndGoBack() {
        LiveListStore.shared.leaveLive { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.isLiveActive = false
                    self.navigationController?.popViewController(animated: true)

                case .failure(let error):
                    self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    // MARK: - State Handling

    private func handleLiveListEvent(_ event: LiveListEvent) {
        switch event {
        case .onLiveEnded(let endedLiveID, _, _):
            // The live stream was ended by the host (audience received the notification)
            if endedLiveID == liveID && role == .audience {
                isLiveActive = false
                view.makeToast("basicStreaming.status.ended".localized) { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                }
            }

        case .onKickedOutOfLive(let kickedLiveID, _, _):
            // Removed from the live room
            if kickedLiveID == liveID {
                isLiveActive = false
                view.makeToast("basicStreaming.status.ended".localized) { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                }
            }

        @unknown default:
            break
        }
    }

    // MARK: - UI Helpers

    /// Update the navigation bar during the live session (host: show on the right side"end the live stream"iconbutton)
    private func updateNavigationBarForLiveState() {
        guard role == .anchor else { return }

        let endLiveButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark.circle"),
            style: .plain,
            target: self,
            action: #selector(endLiveButtonTapped)
        )
        endLiveButton.tintColor = .systemRed

        // Device management + End Live
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )

        navigationItem.rightBarButtonItems = [endLiveButton, settingsButton]
    }

    @objc private func endLiveButtonTapped() {
        // Present a confirmation alert
        let alert = UIAlertController(
            title: "basicStreaming.endLive.confirm.title".localized,
            message: "basicStreaming.endLive.confirm.message".localized,
            preferredStyle: .alert
        )
        let confirmAction = UIAlertAction(title: "common.confirm".localized, style: .destructive) { [weak self] _ in
            self?.endLiveAndGoBack()
        }
        let cancelAction = UIAlertAction(title: "common.cancel".localized, style: .cancel)
        alert.addAction(confirmAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }

    /// Reset to the pre-live state (host sideused after passive termination)
    private func resetToPreLiveState() {
        startLiveButton.isHidden = false
        startLiveButton.isEnabled = true

        // Restore the device management button on the right side of the navigation bar
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        navigationItem.rightBarButtonItem = settingsButton

        // Reopen the camera and microphone for preview
        DeviceStore.shared.openLocalCamera(isFront: true, completion: nil)
        DeviceStore.shared.openLocalMicrophone(completion: nil)
    }

    // MARK: - Cleanup

    /// Clean up live-stream resources when leaving the page
    private func cleanupLiveSession() {
        guard isLiveActive else { return }

        switch role {
        case .anchor:
            DeviceStore.shared.closeLocalCamera()
            DeviceStore.shared.closeLocalMicrophone()
            LiveListStore.shared.endLive { _ in }

        case .audience:
            LiveListStore.shared.leaveLive { _ in }
        }

        isLiveActive = false
    }
}

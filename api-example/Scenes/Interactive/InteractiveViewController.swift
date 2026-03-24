import UIKit
import SnapKit
import Combine
import Toast_Swift
import AtomicXCore

/**
 * Business scenario: real-time interaction page
 *
 * Based on basic push/pull streaming (BasicStreaming), adds real-time interaction features:
 * - barrage chat (BarrageStore)
 * - gift system (GiftStore)
 * - likeFeatures (LikeStore)
 * - beauty effects (BaseBeautyStore)——host only
 * - audio effect settings (AudioEffectStore)——host only
 *
 * APIs involved (basic push/pull streaming):
 * - LiveListStore.shared.createLive(_:completion:) - Hostcreate a live stream
 * - LiveListStore.shared.joinLive(liveID:completion:) - Audiencejoin the live stream
 * - LiveListStore.shared.endLive(completion:) - Hostend the live stream
 * - LiveListStore.shared.leaveLive(completion:) - Audienceleave the live stream
 * - LiveListStore.shared.liveListEventPublisher - live event observation
 * - DeviceStore.shared.openLocalCamera(isFront:completion:) - open the camera
 * - DeviceStore.shared.openLocalMicrophone(completion:) - open the microphone
 * - DeviceStore.shared.closeLocalCamera() - close the camera
 * - DeviceStore.shared.closeLocalMicrophone() - close the microphone
 * - LiveCoreView(viewType:) - video rendering component
 *
 * APIs involved (real-time interaction):
 * - BarrageStore.create(liveID:) - barrage management
 * - GiftStore.create(liveID:) - gift management
 * - GiftStore.giftEventPublisher - giftevent observation (play animations)
 * - LikeStore.create(liveID:) - like management
 * - BaseBeautyStore.shared - beauty management (singleton)
 * - AudioEffectStore.shared - audio effect management (singleton)
 *
 * Different operations are provided based on the user role:
 * - host: push stream + barrage + like (viewing) + beauty + audio effects + device management + gift animation display
 * - audience: play stream + barrage + gift + like + gift animation display
 */
class InteractiveViewController: UIViewController {

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

    /// Barrage interaction component (overlaid on the lower-left area of the video view)
    private lazy var barrageView = BarrageView(liveID: liveID)

    /// Like button component (floating at the bottom-right corner)
    private lazy var likeButton = LikeButton(liveID: liveID)

    /// Gift animation display component (full-screen overlay, shared by hosts and audience users)
    private lazy var giftAnimationView = GiftAnimationView()

    /// Gift management (so that the host side can also observe gift events)
    private lazy var giftStore = GiftStore.create(liveID: liveID)

    /// Gift entry button (displayed only for audience users, in the bottom toolbar)
    private lazy var giftEntryButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        button.setImage(UIImage(systemName: "gift.fill", withConfiguration: config), for: .normal)
        button.tintColor = .systemPink
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.addTarget(self, action: #selector(showGiftPanel), for: .touchUpInside)
        return button
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
        setupDismissKeyboardGesture()
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
        navigationItem.title = liveID

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance

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

    /// Tap the blank area to dismiss the keyboard (covers the entire content area)
    private func setupDismissKeyboardGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false  // Do not block touch events for other controls
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.window?.endEditing(true)
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

    // MARK: - Interactive Component Layout

    /// Set up interactive components during the live session (shared by hosts and audience users)
    private func setupInteractiveComponents() {
        // Barrage component - lower-left area
        view.addSubview(barrageView)
        barrageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview().multipliedBy(0.7)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-8)
            make.height.equalTo(280)
        }

        // Like button - bottom-right corner
        view.addSubview(likeButton)
        likeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.equalTo(barrageView.snp.bottom).offset(10)
        }

        // Display the gift entry button for audience users
        if role == .audience {
            view.addSubview(giftEntryButton)
            giftEntryButton.snp.makeConstraints { make in
                make.trailing.equalTo(likeButton.snp.leading).offset(-5)
                make.centerY.equalTo(likeButton)
                make.width.height.equalTo(40)
            }
        }

        // Gift animation component - full-screen overlay (shared by hosts and audience users)
        view.addSubview(giftAnimationView)
        giftAnimationView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Subscribe to gift events (both hosts and audience users need to see gift animations and barrage messages)
        setupGiftEventBindings()
    }

    /// Subscribe to gift events and play gift animations
    private func setupGiftEventBindings() {
        giftStore.giftEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .onReceiveGift(_, let gift, let count, let sender):
                    // Play a gift animation (full-screen SVGA or barrage slide animation)
                    self?.giftAnimationView.playGiftAnimation(gift: gift, count: count, sender: sender)
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Host Configuration

    private func configureForAnchor() {
        // Configure a custom back button
        setupBackButton(action: #selector(anchorBackTapped))

        // Device management button on the right side of the navigation bar
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

    // MARK: - Audience Configuration

    private func configureForAudience() {
        // Configure the back button
        setupBackButton(action: #selector(audienceBackTapped))

        // Audience users do not have device control buttons
        navigationItem.rightBarButtonItem = nil

        // Automatically join the room after entering
        joinLive()
    }

    // MARK: - Actions

    /// Host back button tapped
    @objc private func anchorBackTapped() {
        if isLiveActive {
            endLiveAndGoBack()
        } else {
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

    /// settings panel entry point (integrating device management, beauty, and audio effects)
    @objc private func settingsTapped() {
        // host's settings paneluses tabs to switch: device management /beauty /audio effects
        let tabbedView = TabbedSettingView(tabs: [
            TabbedSettingView.Tab(
                title: "deviceSetting.title".localized,
                view: DeviceSettingView()
            ),
            TabbedSettingView.Tab(
                title: "interactive.beauty.title".localized,
                view: BeautySettingView()
            ),
            TabbedSettingView.Tab(
                title: "interactive.audioEffect.title".localized,
                view: AudioEffectSettingView()
            ),
        ])
        let panel = SettingPanelController(
            title: "interactive.settings.title".localized,
            contentView: tabbedView
        )
        panel.show(in: self)
    }

    /// Start Live button tapped
    @objc private func startLiveButtonTapped() {
        createLive()
    }

    /// Present the gift panel (half-screen sheet)
    @objc private func showGiftPanel() {
        let giftPanel = GiftPanelView(liveID: liveID)

        // Send result callback
        giftPanel.onSendGiftResult = { [weak self] result in
            switch result {
            case .success:
                break
            case .failure(let error):
                self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
            }
        }

        let panel = SettingPanelController(
            title: "interactive.gift.title".localized,
            contentView: giftPanel,
            backgroundColor: UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1.0)
        )
        panel.show(in: self, height: 320)
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
                    self.liveCoreView.setLiveID(createdLiveInfo.liveID)

                    // Hide the "Start Live" button
                    self.startLiveButton.isHidden = true

                    // Configure the in-live navigation bar and interactive components
                    self.updateNavigationBarForLiveState()
                    self.setupInteractiveComponents()

                    self.view.makeToast(String(format: "basicStreaming.status.created".localized, createdLiveInfo.liveID))

                case .failure(let error):
                    self.startLiveButton.isEnabled = true
                    self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))

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

                    // Show interactive components after joining successfully
                    self.setupInteractiveComponents()

                    self.view.makeToast(String(format: "basicStreaming.status.joined".localized, liveInfo.liveID))

                case .failure(let error):
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
                    BaseBeautyStore.shared.reset()
                    AudioEffectStore.shared.reset()
                    self.isLiveActive = false
                    self.navigationController?.popViewController(animated: true)

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
            if endedLiveID == liveID && role == .audience {
                isLiveActive = false
                view.makeToast("basicStreaming.status.ended".localized) { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                }
            }

        case .onKickedOutOfLive(let kickedLiveID, _, _):
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

    private func setupBackButton(action: Selector) {
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: action
        )
        navigationItem.leftBarButtonItem = backButton
    }

    /// Update the navigation bar during the live session (host: show on the right side"end the live stream"button + device management button)
    private func updateNavigationBarForLiveState() {
        guard role == .anchor else { return }

        let endLiveButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark.circle"),
            style: .plain,
            target: self,
            action: #selector(endLiveButtonTapped)
        )
        endLiveButton.tintColor = .systemRed

        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )

        navigationItem.rightBarButtonItems = [endLiveButton, settingsButton]
    }

    @objc private func endLiveButtonTapped() {
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

    // MARK: - Cleanup

    /// Clean up live-stream resources when leaving the page
    private func cleanupLiveSession() {
        guard isLiveActive else { return }

        switch role {
        case .anchor:
            DeviceStore.shared.closeLocalCamera()
            DeviceStore.shared.closeLocalMicrophone()
            BaseBeautyStore.shared.reset()
            AudioEffectStore.shared.reset()
            LiveListStore.shared.endLive { _ in }

        case .audience:
            LiveListStore.shared.leaveLive { _ in }
        }

        isLiveActive = false
    }
}

// MARK: - TabbedSettingView

/**
 * Tab-switch container component
 *
 * Used to display multiple settings panels as tabs within `SettingPanelController`:
 * - device management (DeviceSettingView)
 * - Beauty settings (BeautySettingView)
 * - audio effect settings (AudioEffectSettingView)
 */
class TabbedSettingView: UIView {

    struct Tab {
        let title: String
        let view: UIView
    }

    // MARK: - Properties

    private let tabs: [Tab]
    private var selectedTabIndex: Int = 0

    // MARK: - UI Components

    private let segmentedControl: UISegmentedControl

    private let containerView: UIView = {
        let view = UIView()
        return view
    }()

    // MARK: - Init

    init(tabs: [Tab]) {
        self.tabs = tabs
        self.segmentedControl = UISegmentedControl(items: tabs.map { $0.title })
        super.init(frame: .zero)
        setupUI()
        setupActions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(segmentedControl)
        addSubview(containerView)

        segmentedControl.selectedSegmentIndex = 0

        segmentedControl.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }

        containerView.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }

        // Add all tab content views to the container
        for (index, tab) in tabs.enumerated() {
            containerView.addSubview(tab.view)
            tab.view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            tab.view.isHidden = (index != 0)
        }
    }

    private func setupActions() {
        segmentedControl.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
    }

    // MARK: - Actions

    @objc private func tabChanged() {
        let newIndex = segmentedControl.selectedSegmentIndex
        guard newIndex != selectedTabIndex else { return }

        // Switch the currently visible tab
        tabs[selectedTabIndex].view.isHidden = true
        tabs[newIndex].view.isHidden = false
        selectedTabIndex = newIndex
    }
}

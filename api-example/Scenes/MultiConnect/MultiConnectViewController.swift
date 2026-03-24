import UIKit
import SnapKit
import Combine
import Toast_Swift
import Kingfisher
import AtomicXCore

/**
 * Business scenario: audience co-guest page (Stage 3: CoGuest)
 *
 * Based on basic push/pull streaming, this page adds audience co-guest features:
 * - audience list (`LiveAudienceStore`)
 * - audience co-guest (`CoGuestStore`) — apply for connections, accept invitations, and go on or off seat
 * - seat management (`LiveSeatStore`) — manage the cameras and microphones of connected audience users
 *
 * APIs involved (basic push/pull streaming):
 * - `LiveListStore.shared.createLive(_:completion:)` - the host creates a live stream
 * - `LiveListStore.shared.joinLive(liveID:completion:)` - the audience joins the live stream
 * - `LiveListStore.shared.endLive(completion:)` - the host ends the live stream
 * - `LiveListStore.shared.leaveLive(completion:)` - the audience leaves the live stream
 * - `LiveListStore.shared.liveListEventPublisher` - live event observation
 * - `DeviceStore.shared.openLocalCamera(isFront:completion:)` - open the camera
 * - `DeviceStore.shared.openLocalMicrophone(completion:)` - open the microphone
 * - `DeviceStore.shared.closeLocalCamera()` - close the camera
 * - `DeviceStore.shared.closeLocalMicrophone()` - close the microphone
 * - `LiveCoreView(viewType:)` - video rendering component
 *
 * APIs involved (audience co-guest):
 * - `LiveAudienceStore.create(liveID:)` - create the audience list store
 * - `LiveAudienceStore.fetchAudienceList(completion:)` - refresh the audience list
 * - `LiveAudienceStore.state` - audience state (`audienceList`, `audienceCount`)
 * - `LiveAudienceStore.liveAudienceEventPublisher` - audience join/leave events
 * - `CoGuestStore.create(liveID:)` - create the co-guest store
 * - `CoGuestStore.applyForSeat(seatIndex:timeout:extraInfo:completion:)` - the audience applies for a connection
 * - `CoGuestStore.cancelApplication(completion:)` - cancel the application
 * - `CoGuestStore.acceptApplication(userID:completion:)` - the host accepts the application
 * - `CoGuestStore.rejectApplication(userID:completion:)` - the host rejects the application
 * - `CoGuestStore.inviteToSeat(userID:seatIndex:timeout:extraInfo:completion:)` - the host invites an audience user to connect
 * - `CoGuestStore.acceptInvitation(inviterID:completion:)` - the audience accepts the invitation
 * - `CoGuestStore.rejectInvitation(inviterID:completion:)` - the audience rejects the invitation
 * - `CoGuestStore.disConnect(completion:)` - disconnect the co-guest session
 * - `CoGuestStore.state` - co-guest state (`connected`, `applicants`, `invitees`)
 * - `CoGuestStore.guestEventPublisher` - audience-side event stream
 * - `CoGuestStore.hostEventPublisher` - host-side event stream
 * - `LiveSeatStore.create(liveID:)` - seat management
 * - `LiveSeatStore.openRemoteCamera(userID:policy:completion:)` - turn on the remote camera
 * - `LiveSeatStore.closeRemoteCamera(userID:completion:)` - turn off the remote camera
 * - `LiveSeatStore.openRemoteMicrophone(userID:policy:completion:)` - turn on the remote microphone
 * - `LiveSeatStore.closeRemoteMicrophone(userID:completion:)` - turn off the remote microphone
 * - `LiveSeatStore.state` - seat state (`seatList`)
 * - `LiveCoreView.videoViewDelegate` - video area interaction delegate (`VideoViewDelegate`)
 *
 * Different operations are provided based on the user role:
 * - host: push stream + view the audience list + invite audience users to connect + handle connection requests + manage connected audience devices
 * - audience: play stream + view the audience list + apply for a connection + respond to invitations + manage their own devices after joining the seat
 */
class MultiConnectViewController: UIViewController {

    // MARK: - Properties

    let role: Role
    let liveID: String

    /// Whether the live session is currently active
    private var isLiveActive: Bool = false

    /// Whether the audience user is already on seat (connection in progress)
    private var isOnSeat: Bool = false

    /// Whether the audience user is currently applying for a connection
    private var isApplying: Bool = false

    private var cancellables = Set<AnyCancellable>()

    /// Stores `CoGuestOverlayView` references keyed by `userID` for later audio/video status updates
    private var overlayViews: [String: CoGuestOverlayView] = [:]

    // MARK: - Stores

    private lazy var liveAudienceStore = LiveAudienceStore.create(liveID: liveID)
    private lazy var coGuestStore = CoGuestStore.create(liveID: liveID)
    private lazy var liveSeatStore = LiveSeatStore.create(liveID: liveID)

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
        view.videoViewDelegate = self
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

    /// audience count label (below the navigation bar on the right, show the current online audience count)
    private lazy var audienceCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        label.layer.cornerRadius = 14
        label.clipsToBounds = true
        label.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(audienceCountTapped))
        label.addGestureRecognizer(tap)
        label.isHidden = true
        return label
    }()

    /// bottom connection button
    private lazy var coGuestButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        button.setImage(UIImage(systemName: "person.wave.2.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(coGuestButtonTapped), for: .touchUpInside)
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
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true

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

    /// Set up state subscriptions related to co-guest connections (called after entering the live session)
    private func setupCoGuestBindings() {
        // Subscribe to audience list changes and update the audience count label
        liveAudienceStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] audienceState in
                self?.updateAudienceCountLabel(count: audienceState.audienceCount)
            }
            .store(in: &cancellables)

        // Subscribe to connection state changes and update the connection button state
        coGuestStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coGuestState in
                self?.handleCoGuestStateUpdate(coGuestState)
            }
            .store(in: &cancellables)

        // Subscribe to seat state changes and update the audio/video status display of connected users (avatar/microphone icons)
        liveSeatStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seatState in
                self?.handleSeatStateUpdate(seatState)
            }
            .store(in: &cancellables)

        if role == .anchor {
            // Host side: observe connection applications from audience users
            coGuestStore.hostEventPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] event in
                    self?.handleHostEvent(event)
                }
                .store(in: &cancellables)
        } else {
            // Audience side: observe host invitations and application responses
            coGuestStore.guestEventPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] event in
                    self?.handleGuestEvent(event)
                }
                .store(in: &cancellables)

            // Audience side: observe the host's operations on local devices (opening/closing the camera or microphone)
            liveSeatStore.liveSeatEventPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] event in
                    self?.handleLiveSeatEvent(event)
                }
                .store(in: &cancellables)
        }

        // Fetch the initial audience list
        liveAudienceStore.fetchAudienceList(completion: nil)
    }

    /// Tap the blank area to dismiss the keyboard
    private func setupDismissKeyboardGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
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
        // Audience count label - below the navigation bar on the right
        view.addSubview(audienceCountLabel)
        audienceCountLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(4)
            make.trailing.equalToSuperview().offset(-12)
            make.height.equalTo(28)
        }

        // Bottom connection button
        view.addSubview(coGuestButton)
        coGuestButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.width.height.equalTo(40)
        }

        updateCoGuestButtonAppearance()

        // Set up state subscriptions related to co-guest connections
        setupCoGuestBindings()
    }

    // MARK: - Host Configuration

    private func configureForAnchor() {
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
        setupBackButton(action: #selector(audienceBackTapped))
        navigationItem.rightBarButtonItem = nil

        // Automatically join the room after entering
        joinLive()
    }

    // MARK: - Actions

    @objc private func anchorBackTapped() {
        if isLiveActive {
            endLiveAndGoBack()
        } else {
            DeviceStore.shared.closeLocalCamera()
            DeviceStore.shared.closeLocalMicrophone()
            navigationController?.popViewController(animated: true)
        }
    }

    @objc private func audienceBackTapped() {
        if isOnSeat {
            // Disconnect from the seat before leaving
            coGuestStore.disConnect { [weak self] result in
                switch result {
                case .success:
                    self?.isOnSeat = false
                    self?.leaveLiveAndGoBack()
                case .failure(let error):
                    DispatchQueue.main.async {
                        self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                    }
                }
            }
        } else if isLiveActive {
            if isApplying {
                coGuestStore.cancelApplication(completion: nil)
            }
            leaveLiveAndGoBack()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc private func settingsTapped() {
        let deviceSettingView = DeviceSettingView()
        let panel = SettingPanelController(
            title: "deviceSetting.title".localized,
            contentView: deviceSettingView
        )
        panel.show(in: self)
    }

    @objc private func startLiveButtonTapped() {
        createLive()
    }

    @objc private func audienceCountTapped() {
        showAudienceListPanel()
    }

    /// Bottom connection button tapped
    @objc private func coGuestButtonTapped() {
        if role == .anchor {
            // Host: open the audience list and select an audience user to initiate a connection
            showAudienceListPanel()
        } else {
            // Audience: apply for or cancel the connection directly
            if isOnSeat {
                // Already on seat → leave the seat
                disconnectCoGuest()
            } else if isApplying {
                // Application in progress → cancel the application
                cancelCoGuestApplication()
            } else {
                // Not connected → apply for a connection
                applyForCoGuest()
            }
        }
    }

    // MARK: - Audience List Panel

    private func showAudienceListPanel() {
        let panelView = AudienceListPanelView(
            role: role,
            audienceStore: liveAudienceStore,
            coGuestStore: coGuestStore
        )

        panelView.onInvite = { [weak self] userID in
            self?.inviteAudienceToSeat(userID: userID)
        }

        let panel = SettingPanelController(
            title: "coGuest.audienceList.title".localized,
            contentView: panelView
        )
        panel.show(in: self, height: 400)
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
                    self.startLiveButton.isHidden = true
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

    // MARK: - Audience Co-Guest Actions

    /// Audience: apply for a connection (go on seat)
    private func applyForCoGuest() {
        isApplying = true
        updateCoGuestButtonAppearance()
        view.makeToast("coGuest.status.applying".localized)

        coGuestStore.applyForSeat(
            seatIndex: -1,
            timeout: 30,
            extraInfo: nil
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break
                case .failure(let error):
                    self?.isApplying = false
                    self?.updateCoGuestButtonAppearance()
                    self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    /// audience: cancel the connection request
    private func cancelCoGuestApplication() {
        coGuestStore.cancelApplication { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isApplying = false
                    self?.updateCoGuestButtonAppearance()
                    self?.view.makeToast("coGuest.status.cancelled".localized)
                case .failure(let error):
                    self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    /// Audience/Host: disconnect the connection
    private func disconnectCoGuest() {
        coGuestStore.disConnect { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.isOnSeat = false
                    self?.isApplying = false
                    if self?.role == .audience {
                        DeviceStore.shared.closeLocalCamera()
                        DeviceStore.shared.closeLocalMicrophone()
                    }
                    self?.updateCoGuestButtonAppearance()
                    self?.view.makeToast("coGuest.status.disconnected".localized)
                case .failure(let error):
                    self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    /// host: invite an audience user to co-guest
    private func inviteAudienceToSeat(userID: String) {
        coGuestStore.inviteToSeat(
            userID: userID,
            seatIndex: -1,
            timeout: 30,
            extraInfo: nil
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.view.makeToast("coGuest.status.invited".localized)
                case .failure(let error):
                    self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    // MARK: - Host-side connected audience device management

    /// Show the device management alert when the host taps a connected audience video area
    private func showSeatUserDeviceAlert(seatInfo: SeatInfo) {
        let userInfo = seatInfo.userInfo
        guard !userInfo.userID.isEmpty else { return }

        let userName = userInfo.userName.isEmpty ? userInfo.userID : userInfo.userName
        let alert = UIAlertController(
            title: String(format: "coGuest.manage.title".localized, userName),
            message: nil,
            preferredStyle: .actionSheet
        )

        // Camera management: determine the current state based on `SeatUserInfo.cameraStatus`
        if userInfo.cameraStatus == .on {
            // The camera is currently on → close it directly without audience confirmation
            alert.addAction(UIAlertAction(title: "coGuest.manage.closeCamera".localized, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.liveSeatStore.closeRemoteCamera(userID: userInfo.userID) { result in
                    DispatchQueue.main.async {
                        if case .failure(let error) = result {
                            self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                        }
                    }
                }
            })
        } else {
            // The camera is currently off → invite the user to turn it on (`unlockOnly`, audience side confirms via alert)
            alert.addAction(UIAlertAction(title: "coGuest.manage.openCamera".localized, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.liveSeatStore.openRemoteCamera(userID: userInfo.userID, policy: .unlockOnly) { result in
                    DispatchQueue.main.async {
                        if case .failure(let error) = result {
                            self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                        }
                    }
                }
            })
        }

        // Microphone management: determine the current state based on `SeatUserInfo.microphoneStatus`
        if userInfo.microphoneStatus == .on {
            // The microphone is currently on → close it directly without audience confirmation
            alert.addAction(UIAlertAction(title: "coGuest.manage.closeMic".localized, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.liveSeatStore.closeRemoteMicrophone(userID: userInfo.userID) { result in
                    DispatchQueue.main.async {
                        if case .failure(let error) = result {
                            self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                        }
                    }
                }
            })
        } else {
            // The microphone is currently off → request the user to turn it on (`unlockOnly`, audience side confirms via alert)
            alert.addAction(UIAlertAction(title: "coGuest.manage.openMic".localized, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.liveSeatStore.openRemoteMicrophone(userID: userInfo.userID, policy: .unlockOnly) { result in
                    DispatchQueue.main.async {
                        if case .failure(let error) = result {
                            self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                        }
                    }
                }
            })
        }

        // Kick the user off the seat
        alert.addAction(UIAlertAction(title: "coGuest.manage.kickOff".localized, style: .destructive) { [weak self] _ in
            self?.liveSeatStore.kickUserOutOfSeat(userID: userInfo.userID) { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                    }
                }
            }
        })

        alert.addAction(UIAlertAction(title: "common.cancel".localized, style: .cancel))
        present(alert, animated: true)
    }

    /// Show the local device management alert when the audience user taps their own video area
    private func showSelfDeviceAlert() {
        let alert = UIAlertController(
            title: "coGuest.selfManage.title".localized,
            message: nil,
            preferredStyle: .actionSheet
        )

        // Get the current device state via DeviceStore
        let deviceState = DeviceStore.shared.state.value

        // Camera management
        if deviceState.cameraStatus == .on {
            alert.addAction(UIAlertAction(title: "coGuest.selfManage.closeCamera".localized, style: .default) { _ in
                DeviceStore.shared.closeLocalCamera()
            })
        } else {
            alert.addAction(UIAlertAction(title: "coGuest.selfManage.openCamera".localized, style: .default) { _ in
                DeviceStore.shared.openLocalCamera(isFront: true, completion: nil)
            })
        }

        // Microphone management
        if deviceState.microphoneStatus == .on {
            alert.addAction(UIAlertAction(title: "coGuest.selfManage.closeMic".localized, style: .default) { _ in
                DeviceStore.shared.closeLocalMicrophone()
            })
        } else {
            alert.addAction(UIAlertAction(title: "coGuest.selfManage.openMic".localized, style: .default) { _ in
                DeviceStore.shared.openLocalMicrophone(completion: nil)
            })
        }

        // Disconnect
        alert.addAction(UIAlertAction(title: "coGuest.selfManage.disconnect".localized, style: .destructive) { [weak self] _ in
            self?.disconnectCoGuest()
        })

        alert.addAction(UIAlertAction(title: "common.cancel".localized, style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - CoGuest State Handling

    private func handleCoGuestStateUpdate(_ state: CoGuestState) {
        let currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""

        // Check whether the current user is on seat
        let wasOnSeat = isOnSeat
        isOnSeat = state.connected.contains { $0.userID == currentUserID }

        if isOnSeat && !wasOnSeat && role == .audience {
            // The audience user has just successfully gone on seat, so open the camera and microphone
            isApplying = false
            DeviceStore.shared.openLocalCamera(isFront: true, completion: nil)
            DeviceStore.shared.openLocalMicrophone(completion: nil)
        } else if !isOnSeat && wasOnSeat && role == .audience {
            // The audience user has been kicked off the seat
            DeviceStore.shared.closeLocalCamera()
            DeviceStore.shared.closeLocalMicrophone()
        }

        updateCoGuestButtonAppearance()
    }

    // MARK: - Host-side Event Handling

    private func handleHostEvent(_ event: HostEvent) {
        switch event {
        case .onGuestApplicationReceived(let guestUser):
            // Received an audience co-guest application; show a confirmation alert
            showApplicationAlert(from: guestUser)

        case .onHostInvitationResponded(let isAccept, let guestUser):
            let name = guestUser.userName.isEmpty ? guestUser.userID : guestUser.userName
            if isAccept {
                view.makeToast(String(format: "coGuest.event.inviteAccepted".localized, name))
            } else {
                view.makeToast(String(format: "coGuest.event.inviteRejected".localized, name))
            }

        case .onGuestApplicationCancelled(let guestUser):
            let name = guestUser.userName.isEmpty ? guestUser.userID : guestUser.userName
            view.makeToast(String(format: "coGuest.event.applicationCancelled".localized, name))

        default:
            break
        }
    }

    // MARK: - Audience-side Event Handling

    private func handleGuestEvent(_ event: GuestEvent) {
        switch event {
        case .onHostInvitationReceived(let hostUser):
            // Received a host connection invitation; show a confirmation alert
            showInvitationAlert(from: hostUser)

        case .onGuestApplicationResponded(let isAccept, let hostUser):
            if isAccept {
                // The application was accepted → the state change will be handled in the state subscription
                isApplying = false
            } else {
                // The application was rejected
                isApplying = false
                updateCoGuestButtonAppearance()
                let name = hostUser.userName.isEmpty ? hostUser.userID : hostUser.userName
                view.makeToast(String(format: "coGuest.event.applicationRejected".localized, name))
            }

        case .onGuestApplicationNoResponse:
            isApplying = false
            updateCoGuestButtonAppearance()
            view.makeToast("coGuest.event.applicationTimeout".localized)

        case .onKickedOffSeat:
            isOnSeat = false
            isApplying = false
            DeviceStore.shared.closeLocalCamera()
            DeviceStore.shared.closeLocalMicrophone()
            updateCoGuestButtonAppearance()
            view.makeToast("coGuest.event.kickedOff".localized)

        case .onHostInvitationCancelled:
            view.makeToast("coGuest.event.invitationCancelled".localized)

        @unknown default:
            break
        }
    }

    // MARK: - Seat State Change Handling

    /// Seat state updates → notify `CoGuestOverlayView` to refresh the audio/video status display
    private func handleSeatStateUpdate(_ seatState: LiveSeatState) {
        // Collect the user IDs currently on seat
        var activeUserIDs = Set<String>()

        for seatInfo in seatState.seatList {
            guard !seatInfo.userInfo.userID.isEmpty else { continue }
            activeUserIDs.insert(seatInfo.userInfo.userID)

            // Update the audio/video state of the corresponding `CoGuestOverlayView`
            if let overlayView = overlayViews[seatInfo.userInfo.userID] {
                overlayView.updateAVStatus(with: seatInfo)
            }
        }

        // Remove overlayView references for users who have left their seats
        overlayViews = overlayViews.filter { activeUserIDs.contains($0.key) }
    }

    // MARK: - Audience: Handle Host Operations on Local Devices

    /// Handle `LiveSeatEvent`: host operations on audience devices
    /// - Close actions (`onLocalCameraClosedByAdmin` / `onLocalMicrophoneClosedByAdmin`): execute directly and notify the audience user
    /// - Open actions (`onLocalCameraOpenedByAdmin` / `onLocalMicrophoneOpenedByAdmin`): show an alert for audience confirmation
    private func handleLiveSeatEvent(_ event: LiveSeatEvent) {
        switch event {
        case .onLocalCameraClosedByAdmin:
            // The host directly closed the audience user's camera
            // DeviceStore.shared.closeLocalCamera()
            view.makeToast("coGuest.device.cameraClosed".localized)

        case .onLocalCameraOpenedByAdmin(_):
            // The host invited the audience user to open the camera (`unlockOnly` mode requires audience confirmation)
            showDeviceRequestAlert(
                title: "coGuest.device.cameraRequest.title".localized,
                message: "coGuest.device.cameraRequest.message".localized,
                onAccept: {
                    DeviceStore.shared.openLocalCamera(isFront: true, completion: nil)
                }
            )

        case .onLocalMicrophoneClosedByAdmin:
            // The host directly closed the audience user's microphone
            // DeviceStore.shared.closeLocalMicrophone()
            view.makeToast("coGuest.device.micClosed".localized)

        case .onLocalMicrophoneOpenedByAdmin(_):
            // The host requested the audience user to open the microphone (`unlockOnly` mode requires audience confirmation)
            showDeviceRequestAlert(
                title: "coGuest.device.micRequest.title".localized,
                message: "coGuest.device.micRequest.message".localized,
                onAccept: { [weak self] in
                    self?.liveSeatStore.unmuteMicrophone(completion: nil)
                    DeviceStore.shared.openLocalMicrophone(completion: nil)
                }
            )

        @unknown default:
            break
        }
    }

    /// Show the device request confirmation alert when the audience receives a host device-opening request
    private func showDeviceRequestAlert(title: String, message: String, onAccept: @escaping () -> Void) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "common.confirm".localized, style: .default) { _ in
            onAccept()
        })

        alert.addAction(UIAlertAction(title: "common.cancel".localized, style: .cancel))
        present(alert, animated: true)
    }

    /// Host: show a confirmation alert when a connection request is received
    private func showApplicationAlert(from guestUser: LiveUserInfo) {
        let name = guestUser.userName.isEmpty ? guestUser.userID : guestUser.userName
        let alert = UIAlertController(
            title: "coGuest.application.title".localized,
            message: String(format: "coGuest.application.message".localized, name),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "coGuest.application.accept".localized, style: .default) { [weak self] _ in
            self?.coGuestStore.acceptApplication(userID: guestUser.userID, completion: nil)
        })

        alert.addAction(UIAlertAction(title: "coGuest.application.reject".localized, style: .destructive) { [weak self] _ in
            self?.coGuestStore.rejectApplication(userID: guestUser.userID, completion: nil)
        })

        present(alert, animated: true)
    }

    /// Audience: show a confirmation alert when a host connection invitation is received
    private func showInvitationAlert(from hostUser: LiveUserInfo) {
        let name = hostUser.userName.isEmpty ? hostUser.userID : hostUser.userName
        let alert = UIAlertController(
            title: "coGuest.invitation.title".localized,
            message: String(format: "coGuest.invitation.message".localized, name),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "coGuest.invitation.accept".localized, style: .default) { [weak self] _ in
            self?.coGuestStore.acceptInvitation(inviterID: hostUser.userID, completion: nil)
        })

        alert.addAction(UIAlertAction(title: "coGuest.invitation.reject".localized, style: .destructive) { [weak self] _ in
            self?.coGuestStore.rejectInvitation(inviterID: hostUser.userID, completion: nil)
        })

        present(alert, animated: true)
    }

    // MARK: - State Handling

    private func handleLiveListEvent(_ event: LiveListEvent) {
        switch event {
        case .onLiveEnded(let endedLiveID, _, _):
            if endedLiveID == liveID && role == .audience {
                isLiveActive = false
                isOnSeat = false
                view.makeToast("basicStreaming.status.ended".localized) { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                }
            }

        case .onKickedOutOfLive(let kickedLiveID, _, _):
            if kickedLiveID == liveID {
                isLiveActive = false
                isOnSeat = false
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

    /// update the audience count labeldisplay
    private func updateAudienceCountLabel(count: UInt) {
        if count > 0 {
            let text = String(format: "coGuest.audienceCount".localized, count)
            audienceCountLabel.text = "  \(text)  "
            audienceCountLabel.isHidden = false
        } else {
            audienceCountLabel.isHidden = true
        }
    }

    /// Update the appearance and icon of the bottom connection button
    private func updateCoGuestButtonAppearance() {
        if role == .anchor {
            // Host side: always display the connection button as "invite to connect"
            coGuestButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            coGuestButton.setImage(UIImage(systemName: "person.wave.2.fill", withConfiguration: config), for: .normal)
        } else {
            // Audience side: update the button based on the current state
            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            if isOnSeat {
                // Connected → red with a disconnect icon
                coGuestButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
                coGuestButton.setImage(UIImage(systemName: "phone.down.fill", withConfiguration: config), for: .normal)
            } else if isApplying {
                // Application in progress → orange with a waiting icon
                coGuestButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
                coGuestButton.setImage(UIImage(systemName: "clock.fill", withConfiguration: config), for: .normal)
            } else {
                // Not connected → green with a connection icon
                coGuestButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
                coGuestButton.setImage(UIImage(systemName: "person.wave.2.fill", withConfiguration: config), for: .normal)
            }
        }
    }

    // MARK: - Cleanup

    private func cleanupLiveSession() {
        guard isLiveActive else { return }

        // Disconnect first
        if isOnSeat {
            coGuestStore.disConnect { _ in }
        }

        switch role {
        case .anchor:
            DeviceStore.shared.closeLocalCamera()
            DeviceStore.shared.closeLocalMicrophone()
            LiveListStore.shared.endLive { _ in }

        case .audience:
            if isOnSeat {
                DeviceStore.shared.closeLocalCamera()
                DeviceStore.shared.closeLocalMicrophone()
            }
            LiveListStore.shared.leaveLive { _ in }
        }

        isLiveActive = false
        isOnSeat = false
        overlayViews.removeAll()
    }
}

// MARK: - VideoViewDelegate

extension MultiConnectViewController: VideoViewDelegate {

    /// Create the foreground overlay view for a connected audience user (avatar + microphone status + nickname label)
    func createCoGuestView(seatInfo: SeatInfo, viewLayer: ViewLayer) -> UIView? {
        switch viewLayer {
        case .foreground:
            // Foreground layer: avatar (shown when the camera is off) + microphone status icon + nickname label
            let overlayView = CoGuestOverlayView(seatInfo: seatInfo)
            overlayView.onTap = { [weak self] info in
                self?.handleCoGuestViewTapped(seatInfo: info)
            }
            // Store the reference for later audio/video status updates
            overlayViews[seatInfo.userInfo.userID] = overlayView
            return overlayView

        case .background:
            return nil

        @unknown default:
            return nil
        }
    }

    func createCoHostView(seatInfo: SeatInfo, viewLayer: ViewLayer) -> UIView? {
        return nil
    }

    func createBattleView(seatInfo: SeatInfo) -> UIView? {
        return nil
    }

    func createBattleContainerView() -> UIView? {
        return nil
    }

    /// Handle taps on the connected user's video area
    private func handleCoGuestViewTapped(seatInfo: SeatInfo) {
        let currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""

        if role == .anchor {
            // Host tapped a connected audience video area → show device management
            if seatInfo.userInfo.userID != currentUserID {
                showSeatUserDeviceAlert(seatInfo: seatInfo)
            }
        } else {
            // Audience user tapped their own video area → manage local devices
            if seatInfo.userInfo.userID == currentUserID {
                showSelfDeviceAlert()
            }
        }
    }
}

// MARK: - AudienceListPanelView

/// Audience list panel - displays online audience users, with a connection button on the host side
class AudienceListPanelView: UIView {

    var onInvite: ((String) -> Void)?

    private let role: Role
    private let audienceStore: LiveAudienceStore
    private let coGuestStore: CoGuestStore
    private var cancellables = Set<AnyCancellable>()
    private var audienceList: [LiveUserInfo] = []
    private var connectedUserIDs: Set<String> = []
    private var invitedUserIDs: Set<String> = []

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.delegate = self
        table.dataSource = self
        table.register(AudienceCell.self, forCellReuseIdentifier: "AudienceCell")
        table.rowHeight = 56
        table.separatorInset = UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 0)
        table.backgroundColor = .clear
        return table
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "coGuest.audienceList.empty".localized
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15)
        return label
    }()

    init(role: Role, audienceStore: LiveAudienceStore, coGuestStore: CoGuestStore) {
        self.role = role
        self.audienceStore = audienceStore
        self.coGuestStore = coGuestStore
        super.init(frame: .zero)
        setupUI()
        setupBindings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(tableView)
        addSubview(emptyLabel)

        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func setupBindings() {
        // Subscribe to audience list changes
        audienceStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.audienceList = state.audienceList
                self?.emptyLabel.isHidden = !state.audienceList.isEmpty
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        // Subscribe to connection state changes to update the connection button state
        coGuestStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectedUserIDs = Set(state.connected.map { $0.userID })
                self?.invitedUserIDs = Set(state.invitees.map { $0.userID })
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        // Refresh the audience list once
        audienceStore.fetchAudienceList(completion: nil)
    }
}

extension AudienceListPanelView: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return audienceList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AudienceCell", for: indexPath) as! AudienceCell
        let user = audienceList[indexPath.row]
        let isConnected = connectedUserIDs.contains(user.userID)
        let isInvited = invitedUserIDs.contains(user.userID)
        cell.configure(with: user, showInviteButton: role == .anchor, isConnected: isConnected, isInvited: isInvited)
        cell.onInvite = { [weak self] userID in
            self?.onInvite?(userID)
        }
        return cell
    }
}

// MARK: - AudienceCell

/// Audience list cell - avatar + username + connection button (displayed only on the host side)
class AudienceCell: UITableViewCell {

    var onInvite: ((String) -> Void)?
    private var userID: String = ""

    private let avatarView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 18
        imageView.backgroundColor = .systemGray4
        return imageView
    }()

    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15)
        return label
    }()

    private lazy var inviteButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        button.layer.cornerRadius = 14
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        button.addTarget(self, action: #selector(inviteTapped), for: .touchUpInside)
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(avatarView)
        avatarView.addSubview(avatarLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(inviteButton)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }

        avatarLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(inviteButton.snp.leading).offset(-8)
        }

        inviteButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.height.equalTo(28)
        }
    }

    func configure(with user: LiveUserInfo, showInviteButton: Bool, isConnected: Bool, isInvited: Bool) {
        userID = user.userID
        nameLabel.text = user.userName.isEmpty ? user.userID : user.userName
        avatarLabel.text = String(user.userID.prefix(1)).uppercased()

        if showInviteButton {
            inviteButton.isHidden = false
            if isConnected {
                inviteButton.setTitle("coGuest.audienceList.connected".localized, for: .normal)
                inviteButton.backgroundColor = UIColor.systemGray5
                inviteButton.setTitleColor(.secondaryLabel, for: .normal)
                inviteButton.isEnabled = false
            } else if isInvited {
                inviteButton.setTitle("coGuest.audienceList.inviting".localized, for: .normal)
                inviteButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
                inviteButton.setTitleColor(.systemOrange, for: .normal)
                inviteButton.isEnabled = false
            } else {
                inviteButton.setTitle("coGuest.audienceList.invite".localized, for: .normal)
                inviteButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
                inviteButton.setTitleColor(.systemBlue, for: .normal)
                inviteButton.isEnabled = true
            }
        } else {
            inviteButton.isHidden = true
        }

        // Load the avatar
        if !user.avatarURL.isEmpty, let url = URL(string: user.avatarURL) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.avatarView.image = image
                        self?.avatarLabel.isHidden = true
                    }
                }
            }.resume()
        } else {
            avatarView.image = nil
            avatarLabel.isHidden = false
        }
    }

    @objc private func inviteTapped() {
        onInvite?(userID)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.image = nil
        avatarLabel.isHidden = false
        inviteButton.isHidden = true
        inviteButton.isEnabled = true
    }
}

// MARK: - CoGuestOverlayView

/// Connected user video overlay - avatar (shown when the camera is off) + microphone status icon + bottom nickname label
class CoGuestOverlayView: UIView {

    var onTap: ((SeatInfo) -> Void)?
    private var seatInfo: SeatInfo

    /// Avatar container (displayed when the camera is off)
    private let avatarContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.darkGray
        view.isHidden = true
        return view
    }()

    /// avatar image
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 30
        imageView.backgroundColor = .systemGray4
        return imageView
    }()

    /// avatar label (show the initial when no avatar URL is available)
    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    /// Microphone status icon
    private let micIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()

    /// Bottom nickname label
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        return label
    }()

    init(seatInfo: SeatInfo) {
        self.seatInfo = seatInfo
        super.init(frame: .zero)
        setupUI()
        updateAVStatus()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        isUserInteractionEnabled = true

        // Avatar container (full-screen overlay, displayed when the camera is off)
        addSubview(avatarContainerView)
        avatarContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        avatarContainerView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(60)
        }

        avatarImageView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        // Microphone status icon (top-right corner)
        addSubview(micIconView)
        micIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().offset(-4)
            make.width.height.equalTo(18)
        }

        // Bottom nickname label
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().offset(-4)
            make.bottom.equalToSuperview().offset(-4)
            make.height.equalTo(20)
        }

        // Display the nickname (hide it if this is the current user)
        let userName = seatInfo.userInfo.userName
        nameLabel.text = userName.isEmpty ? seatInfo.userInfo.userID : userName
        let currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        nameLabel.isHidden = seatInfo.userInfo.userID == currentUserID

        // Load the avatar
        loadAvatar()

        // Add a tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        addGestureRecognizer(tap)
    }

    /// Load the user avatar
    private func loadAvatar() {
        let userInfo = seatInfo.userInfo
        if !userInfo.avatarURL.isEmpty, let url = URL(string: userInfo.avatarURL) {
            avatarImageView.kf.setImage(
                with: url,
                placeholder: UIImage(systemName: "person.circle.fill")
            ) { [weak self] result in
                if case .success = result {
                    self?.avatarLabel.isHidden = true
                }
            }
        } else {
            avatarImageView.image = nil
            avatarLabel.isHidden = false
            avatarLabel.text = String(userInfo.userID.prefix(1)).uppercased()
        }
    }

    /// Update the audio/video status display
    func updateAVStatus(with updatedSeatInfo: SeatInfo? = nil) {
        if let updatedSeatInfo = updatedSeatInfo {
            self.seatInfo = updatedSeatInfo
        }

        let userInfo = seatInfo.userInfo

        // Show the avatar when the camera is off
        avatarContainerView.isHidden = (userInfo.cameraStatus == .on)

        // Microphone status icon
        let micConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        if userInfo.microphoneStatus == .on {
            micIconView.image = UIImage(systemName: "mic.fill", withConfiguration: micConfig)
            micIconView.tintColor = .white
        } else {
            micIconView.image = UIImage(systemName: "mic.slash.fill", withConfiguration: micConfig)
            micIconView.tintColor = .systemRed
        }
    }

    @objc private func viewTapped() {
        onTap?(seatInfo)
    }
}

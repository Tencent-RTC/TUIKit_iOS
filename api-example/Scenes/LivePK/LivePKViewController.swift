import UIKit
import SnapKit
import Combine
import Toast_Swift
import AtomicXCore

/**
 * Business scenario: live PK battle page
 *
 * Based on real-time interaction (`Interactive`), this page adds host cross-room co-hosting and PK battle features:
 * - host co-hosting (`CoHostStore`): initiate/accept/reject/exit cross-room connections
 * - PK battle (`BattleStore`): initiate/accept/reject/exit PK battles and display scores in real time
 *
 * APIs involved (basic push/pull streaming + real-time interaction):
 * - `LiveListStore.shared.createLive(_:completion:)` - the host creates a live stream
 * - `LiveListStore.shared.joinLive(liveID:completion:)` - the audience joins the live stream
 * - `LiveListStore.shared.endLive(completion:)` - the host ends the live stream
 * - `LiveListStore.shared.leaveLive(completion:)` - the audience leaves the live stream
 * - `LiveListStore.shared.fetchLiveList(cursor:count:completion:)` - fetch the live stream list
 * - `LiveListStore.shared.liveListEventPublisher` - live event observation
 * - `DeviceStore.shared` - camera and microphone management
 * - `BarrageStore.create(liveID:)` - barrage management
 * - `GiftStore.create(liveID:)` - gift management
 * - `LikeStore.create(liveID:)` - like management
 * - `LiveCoreView(viewType:)` - video rendering component
 *
 * APIs involved (co-host + PK):
 * - `CoHostStore.create(liveID:)` - cross-room co-host management
 * - `CoHostStore.requestHostConnection(targetHost:layoutTemplate:timeout:extraInfo:completion:)` - initiate a co-host connection
 * - `CoHostStore.acceptHostConnection(fromHostLiveID:completion:)` - accept a co-host connection
 * - `CoHostStore.rejectHostConnection(fromHostLiveID:completion:)` - reject a co-host connection
 * - `CoHostStore.exitHostConnection(completion:)` - exit a co-host connection
 * - `CoHostStore.coHostEventPublisher` - co-host event observation
 * - `BattleStore.create(liveID:)` - PK battle management
 * - `BattleStore.requestBattle(config:userIDList:timeout:completion:)` - initiate a PK battle
 * - `BattleStore.acceptBattle(battleID:completion:)` - accept a PK battle
 * - `BattleStore.rejectBattle(battleID:completion:)` - reject a PK battle
 * - `BattleStore.exitBattle(battleID:completion:)` - exit a PK battle
 * - `BattleStore.battleEventPublisher` - PK event observation
 *
 * Different operations are provided based on the user role:
 * - host: push stream + barrage + like + gift animation + initiate connections + start PK battles + display PK scores
 * - audience: play stream + barrage + gift + like + display PK status
 */
class LivePKViewController: UIViewController {

    // MARK: - Properties

    var role: Role = .audience
    var liveID: String = ""

    /// Whether the live session is currently active
    private var isLiveActive: Bool = false

    /// Host co-host connection state
    private var isCoHostConnected: Bool = false

    /// Whether a PK battle is currently in progress
    private var isBattling: Bool = false

    /// Current PK battle ID
    private var currentBattleID: String?

    /// liveID of the connected peer
    private var connectedHostLiveID: String?

    /// `CoHostStore` instance (initialized after the live session is created or joined)
    private var coHostStore: CoHostStore?

    /// `BattleStore` instance (initialized after the live session is created or joined)
    private var battleStore: BattleStore?

    /// `GiftStore` instance
    private var giftStore: GiftStore?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(role: Role, liveID: String) {
        self.role = role
        self.liveID = liveID
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    /// Compatible with the previous property injection approach
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Components

    /// Video rendering area - the host uses `pushView`, and the audience uses `playView`
    private lazy var liveCoreView: LiveCoreView = {
        let viewType: AtomicXCore.CoreViewType = (role == .anchor) ? .pushView : .playView
        let view = LiveCoreView(viewType: viewType)
        view.setLiveID(liveID)
        view.backgroundColor = .black
        return view
    }()

    /// "Start Live" button (used only by the host)
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

    /// Barrage interaction component
    private lazy var barrageView = BarrageView(liveID: liveID)

    /// like buttoncomponent
    private lazy var likeButton = LikeButton(liveID: liveID)

    /// Gift animation display component
    private lazy var giftAnimationView = GiftAnimationView()

    /// gift entry button (audience only)
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

    // MARK: - host-side co-host/PK action buttons

    /// co-host action button
    private lazy var coHostButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        button.setImage(UIImage(systemName: "link", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.systemOrange
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(coHostButtonTapped), for: .touchUpInside)
        return button
    }()

    /// PK action button (available only after connecting)
    private lazy var battleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("PK", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.systemRed
        button.layer.cornerRadius = 20
        button.isEnabled = false
        button.alpha = 0.5
        button.addTarget(self, action: #selector(battleButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - PK score display UI

    /// PK score container
    private lazy var pkScoreView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.layer.cornerRadius = 8
        view.isHidden = true
        return view
    }()

    /// PK status label
    private lazy var pkStatusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemYellow
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textAlignment = .center
        label.text = "livePK.status.battling".localized
        return label
    }()

    /// multi-user score display stack view (subviews generated dynamically)
    private lazy var scoreStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 4
        return stack
    }()

    /// Current PK participant score data: [(userID, userName, score, isMe)]
    private var battleScoreEntries: [(userID: String, userName: String, score: UInt, isMe: Bool)] = []

    /// PK countdown label
    private lazy var pkTimerLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(0.8)
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    /// PK countdown timer
    private var pkTimer: Timer?

    /// PK end time
    private var pkEndTime: UInt = 0

    /// connection status indicator label (audience sideis also visible)
    private lazy var connectionStatusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.isHidden = true
        return label
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

        // connection stateindicator (below the top navigation bar)
        view.addSubview(connectionStatusLabel)
        connectionStatusLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(44)
            make.height.equalTo(24)
            make.width.greaterThanOrEqualTo(120)
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
        // Observe live events
        LiveListStore.shared.liveListEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleLiveListEvent(event)
            }
            .store(in: &cancellables)
    }

    private func setupDismissKeyboardGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.window?.endEditing(true)
    }

    private func configureForRole() {
        switch role {
        case .anchor:
            configureForAnchor()
        case .audience:
            configureForAudience()
        }
    }

    // MARK: - Interactive Component Layout

    /// Set up interactive components during the live session
    private func setupInteractiveComponents() {
        // barragecomponent - lower-left area
        view.addSubview(barrageView)
        barrageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview().multipliedBy(0.5)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-8)
            make.height.equalTo(280)
        }

        // like button - bottom-right corner
        view.addSubview(likeButton)
        likeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.equalTo(barrageView.snp.bottom).offset(10)
        }

        // audiencedisplaygift entry button
        if role == .audience {
            view.addSubview(giftEntryButton)
            giftEntryButton.snp.makeConstraints { make in
                make.trailing.equalTo(likeButton.snp.leading).offset(-5)
                make.centerY.equalTo(likeButton)
                make.width.height.equalTo(40)
            }
        }

        // gift animation component - full-screen overlay
        view.addSubview(giftAnimationView)
        giftAnimationView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Subscribe to gift events
        setupGiftEventBindings()

        // Host side: show the co-host and PK action buttons
        if role == .anchor {
            setupAnchorPKControls()
        }

        // PK score display area (shared by hosts and audience users)
        setupPKScoreView()
    }

    /// Subscribe to gift events and play gift animations
    private func setupGiftEventBindings() {
        giftStore?.giftEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .onReceiveGift(_, let gift, let count, let sender):
                    self?.giftAnimationView.playGiftAnimation(gift: gift, count: count, sender: sender)
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    /// Host-side co-host and PK button layout (horizontally aligned with the like button)
    private func setupAnchorPKControls() {
        view.addSubview(coHostButton)
        view.addSubview(battleButton)

        coHostButton.snp.makeConstraints { make in
            make.trailing.equalTo(likeButton.snp.leading).offset(-5)
            make.centerY.equalTo(likeButton)
            make.width.height.equalTo(40)
        }

        battleButton.snp.makeConstraints { make in
            make.trailing.equalTo(coHostButton.snp.leading).offset(-5)
            make.centerY.equalTo(likeButton)
            make.width.height.equalTo(40)
        }
    }

    /// Layout for the PK score display area
    private func setupPKScoreView() {
        view.addSubview(pkScoreView)
        pkScoreView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(50)
            make.width.greaterThanOrEqualTo(160)
            make.width.lessThanOrEqualToSuperview().offset(-32)
        }

        // PK status label
        pkScoreView.addSubview(pkStatusLabel)
        pkStatusLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.centerX.equalToSuperview()
        }

        // Dynamic score area
        pkScoreView.addSubview(scoreStackView)
        scoreStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalTo(pkStatusLabel.snp.bottom).offset(4)
        }

        // Countdown label
        pkScoreView.addSubview(pkTimerLabel)
        pkTimerLabel.snp.makeConstraints { make in
            make.top.equalTo(scoreStackView.snp.bottom).offset(2)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-6)
        }
    }

    /// Rebuild the score UI based on the participant list
    private func rebuildScoreViews(battleUsers: [SeatUserInfo]) {
        // Remove the old subviews
        scoreStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        battleScoreEntries = []

        let currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let userColors: [UIColor] = [.systemBlue, .systemRed, .systemGreen, .systemPurple, .systemOrange]

        for (index, user) in battleUsers.enumerated() {
            let isMe = user.userID == currentUserID
            let color = userColors[index % userColors.count]

            // Score item for each user: name + score, arranged vertically
            let container = UIView()

            let nameLabel = UILabel()
            nameLabel.text = isMe ? "livePK.battle.me".localized : user.userName
            nameLabel.font = .systemFont(ofSize: 10, weight: .medium)
            nameLabel.textColor = color.withAlphaComponent(0.8)
            nameLabel.textAlignment = .center
            nameLabel.lineBreakMode = .byTruncatingTail

            let scoreLabel = UILabel()
            scoreLabel.text = "0"
            scoreLabel.font = .monospacedDigitSystemFont(ofSize: 24, weight: .bold)
            scoreLabel.textColor = color
            scoreLabel.textAlignment = .center
            scoreLabel.tag = 100 + index  // Use tags to simplify later score updates

            container.addSubview(nameLabel)
            container.addSubview(scoreLabel)
            nameLabel.snp.makeConstraints { make in
                make.top.equalToSuperview()
                make.leading.trailing.equalToSuperview()
            }
            scoreLabel.snp.makeConstraints { make in
                make.top.equalTo(nameLabel.snp.bottom).offset(2)
                make.leading.trailing.equalToSuperview()
                make.bottom.equalToSuperview()
            }

            // Add a separator before each user except the first
            if index > 0 {
                let separator = UILabel()
                separator.text = ":"
                separator.font = .systemFont(ofSize: 16, weight: .bold)
                separator.textColor = .white.withAlphaComponent(0.6)
                separator.textAlignment = .center
                separator.setContentHuggingPriority(.required, for: .horizontal)
                separator.setContentCompressionResistancePriority(.required, for: .horizontal)
                scoreStackView.addArrangedSubview(separator)
                separator.snp.makeConstraints { make in
                    make.width.equalTo(12)
                }
            }

            scoreStackView.addArrangedSubview(container)
            battleScoreEntries.append((userID: user.userID, userName: user.userName, score: 0, isMe: isMe))
        }
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

        // Display the "Start Live" button
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
        if isLiveActive {
            leaveLiveAndGoBack()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc private func settingsTapped() {
        let panel = SettingPanelController(
            title: "deviceSetting.title".localized,
            contentView: DeviceSettingView()
        )
        panel.show(in: self)
    }

    @objc private func startLiveButtonTapped() {
        createLive()
    }

    @objc private func showGiftPanel() {
        guard let giftStore = giftStore else { return }
        let giftPanel = GiftPanelView(liveID: liveID)
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

                    // Initialize the co-host and PK stores
                    self.coHostStore = CoHostStore.create(liveID: createdLiveInfo.liveID)
                    self.battleStore = BattleStore.create(liveID: createdLiveInfo.liveID)
                    self.giftStore = GiftStore.create(liveID: createdLiveInfo.liveID)

                    // Hide the "Start Live" button
                    self.startLiveButton.isHidden = true

                    // Configure the in-live navigation bar and interactive components
                    self.updateNavigationBarForLiveState()
                    self.setupInteractiveComponents()

                    // Subscribe to co-host and PK events
                    self.setupCoHostBindings()
                    self.setupBattleBindings()

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

                    // Initialize the store (audience sidealso needs to observe PK state)
                    self.coHostStore = CoHostStore.create(liveID: liveInfo.liveID)
                    self.battleStore = BattleStore.create(liveID: liveInfo.liveID)
                    self.giftStore = GiftStore.create(liveID: liveInfo.liveID)

                    // Show interactive components after joining successfully
                    self.setupInteractiveComponents()

                    // audience sidealso observes co-host and PK state changes
                    self.setupCoHostStateObserver()
                    self.setupBattleStateObserver()

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

        // Exit the PK battle and the connection first
        if isBattling, let battleID = currentBattleID {
            battleStore?.exitBattle(battleID: battleID) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.handleBattleEnded()
                    case .failure(let error):
                        self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                    }
                }
            }
        }
        if isCoHostConnected {
            coHostStore?.exitHostConnection { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.isCoHostConnected = false
                        self?.connectedHostLiveID = nil
                    case .failure(let error):
                        self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                    }
                }
            }
        }

        LiveListStore.shared.endLive { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    DeviceStore.shared.closeLocalCamera()
                    DeviceStore.shared.closeLocalMicrophone()
                    self.isLiveActive = false
                    self.stopPKTimer()
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
                    self.stopPKTimer()
                    self.navigationController?.popViewController(animated: true)

                case .failure(let error):
                    self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    // MARK: - Host Co-Host Actions

    /// Co-host button tapped: switch actions based on the current state
    @objc private func coHostButtonTapped() {
        if isCoHostConnected {
            // Already connected, disconnect after secondary confirmation
            confirmExitCoHost()
        } else {
            // Not connected: show the list of hosts available for connection
            showHostSelectionPanel()
        }
    }

    /// Show the host list and select a host to connect to
    private func showHostSelectionPanel() {
        let userListView = CoHostUserListView(currentLiveID: liveID)

        userListView.onSelectHost = { [weak self] liveInfo in
            self?.requestCoHostConnection(targetLiveID: liveInfo.liveID)
        }

        userListView.onEmptyList = { [weak self] in
            self?.view.makeToast("livePK.coHost.emptyList".localized)
        }

        userListView.onLoadError = { [weak self] error in
            self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
        }

        userListView.show(in: self)
    }

    /// Initiate a cross-room co-host request
    private func requestCoHostConnection(targetLiveID: String) {
        view.makeToast("livePK.coHost.connecting".localized)

        coHostStore?.requestHostConnection(
            targetHost: targetLiveID,
            layoutTemplate: .hostDynamicGrid,
            timeout: 30,
            extraInfo: "",
            completion: { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        break // The connection request has been sent; wait for the other side to respond via `CoHostEvent`
                    case .failure(let error):
                        self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                    }
                }
            }
        )
    }

    /// Confirm disconnecting the connection
    private func confirmExitCoHost() {
        let alert = UIAlertController(
            title: "livePK.coHost.disconnect".localized,
            message: "livePK.coHost.confirm.disconnect".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "common.confirm".localized, style: .destructive) { [weak self] _ in
            self?.exitCoHost()
        })
        alert.addAction(UIAlertAction(title: "common.cancel".localized, style: .cancel))
        present(alert, animated: true)
    }

    /// exit the connection
    private func exitCoHost() {
        coHostStore?.exitHostConnection { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    self.isCoHostConnected = false
                    self.connectedHostLiveID = nil
                    self.updateCoHostButtonState()
                    self.updateConnectionStatus()
                    self.view.makeToast("livePK.coHost.disconnected".localized)

                    // If a PK battle is in progress, end it as well
                    if self.isBattling, let battleID = self.currentBattleID {
                        self.battleStore?.exitBattle(battleID: battleID) { exitResult in
                            DispatchQueue.main.async {
                                switch exitResult {
                                case .success:
                                    self.handleBattleEnded()
                                case .failure(let error):
                                    self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                                }
                            }
                        }
                    }

                case .failure(let error):
                    self.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    // MARK: - PK Battle Actions

    /// PK button tapped
    @objc private func battleButtonTapped() {
        if isBattling {
            // PK in progress, confirm ending it
            confirmEndBattle()
        } else {
            // not in a PK battle, start a PK battle
            startBattle()
        }
    }

    /// start a PK battle
    private func startBattle() {
        guard isCoHostConnected else { return }

        // Get the connected host userIDs (excluding the current user)
        let currentUserID = LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
        let connectedUsers = coHostStore?.state.value.connected ?? []
        let userIDList = connectedUsers.map { $0.userID }.filter { $0 != currentUserID }

        guard !userIDList.isEmpty else {
            view.makeToast("livePK.coHost.emptyList".localized)
            return
        }

        view.makeToast("livePK.battle.requesting".localized)

        let config = BattleConfig(duration: 30, needResponse: true, extensionInfo: "")
        battleStore?.requestBattle(config: config, userIDList: userIDList, timeout: 10) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break // The PK request has been sent; wait for the other side to respond via `BattleEvent`
                case .failure(let error):
                    self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    /// Confirm ending the PK battle
    private func confirmEndBattle() {
        let alert = UIAlertController(
            title: "livePK.battle.end".localized,
            message: "livePK.battle.confirm.end".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "common.confirm".localized, style: .destructive) { [weak self] _ in
            self?.exitBattle()
        })
        alert.addAction(UIAlertAction(title: "common.cancel".localized, style: .cancel))
        present(alert, animated: true)
    }

    /// exit the PK battle
    private func exitBattle() {
        guard let battleID = currentBattleID else { return }
        battleStore?.exitBattle(battleID: battleID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.handleBattleEnded()
                    self?.view.makeToast("livePK.battle.ended".localized)
                case .failure(let error):
                    self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                }
            }
        }
    }

    // MARK: - Cohost event binding (host side)

    private func setupCoHostBindings() {
        coHostStore?.coHostEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleCoHostEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleCoHostEvent(_ event: CoHostEvent) {
        switch event {
        case .onCoHostRequestReceived(let inviter, _):
            // Received a connection request from another host
            showCoHostRequestAlert(from: inviter)

        case .onCoHostRequestAccepted(let invitee):
            // The other side accepted the connection
            isCoHostConnected = true
            connectedHostLiveID = invitee.liveID
            updateCoHostButtonState()
            updateConnectionStatus()
            view.makeToast(String(format: "livePK.coHost.request.accepted".localized, invitee.userName.isEmpty ? invitee.userID : invitee.userName))

        case .onCoHostRequestRejected(let invitee):
            view.makeToast(String(format: "livePK.coHost.request.rejected".localized, invitee.userName.isEmpty ? invitee.userID : invitee.userName))

        case .onCoHostRequestTimeout(_, _):
            view.makeToast("livePK.coHost.request.timeout".localized)

        case .onCoHostRequestCancelled(_, _):
            view.makeToast("livePK.coHost.request.cancelled".localized)

        case .onCoHostUserJoined(let userInfo):
            isCoHostConnected = true
            connectedHostLiveID = userInfo.liveID
            updateCoHostButtonState()
            updateConnectionStatus()
            view.makeToast("livePK.coHost.connected".localized)

        case .onCoHostUserLeft(let userInfo):
            isCoHostConnected = false
            connectedHostLiveID = nil
            updateCoHostButtonState()
            updateConnectionStatus()
            view.makeToast(String(format: "livePK.coHost.userLeft".localized, userInfo.userName.isEmpty ? userInfo.userID : userInfo.userName))

            // When the connection is disconnected, automatically end the PK battle if one is in progress
            if isBattling {
                handleBattleEnded()
            }

        @unknown default:
            break
        }
    }

    /// Connection request alert
    private func showCoHostRequestAlert(from inviter: SeatUserInfo) {
        let name = inviter.userName.isEmpty ? inviter.userID : inviter.userName
        let alert = UIAlertController(
            title: "livePK.coHost.connect".localized,
            message: String(format: "livePK.coHost.request.received".localized, name),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "coGuest.application.accept".localized, style: .default) { [weak self] _ in
            self?.coHostStore?.acceptHostConnection(fromHostLiveID: inviter.liveID) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        break // The connection was accepted successfully; follow-up handling is performed via `CoHostEvent`
                    case .failure(let error):
                        self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "coGuest.application.reject".localized, style: .cancel) { [weak self] _ in
            self?.coHostStore?.rejectHostConnection(fromHostLiveID: inviter.liveID) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        break // Rejected successfully
                    case .failure(let error):
                        self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Battle event binding (host side)

    private func setupBattleBindings() {
        battleStore?.battleEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleBattleEvent(event)
            }
            .store(in: &cancellables)

        // Subscribe to PK state changes (score updates)
        setupBattleStateObserver()
    }

    private func handleBattleEvent(_ event: BattleEvent) {
        switch event {
        case .onBattleStarted(let battleInfo, let inviter, let invitees):
            let battleUsers = [inviter] + invitees
            handleBattleStarted(battleInfo: battleInfo, battleUsers: battleUsers)

        case .onBattleEnded(_, _):
            handleBattleEnded()
            view.makeToast("livePK.battle.ended".localized)

        case .onBattleRequestReceived(let battleID, let inviter, _):
            // PK request alert
            showBattleRequestAlert(battleID: battleID, from: inviter)

        case .onUserJoinBattle(_, _):
            // User joined the PK battle
            break

        @unknown default:
            break
        }
    }

    /// PK request alert
    private func showBattleRequestAlert(battleID: String, from inviter: SeatUserInfo) {
        let name = inviter.userName.isEmpty ? inviter.userID : inviter.userName
        let alert = UIAlertController(
            title: "livePK.battle.title".localized,
            message: String(format: "livePK.battle.request.received".localized, name),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "coGuest.application.accept".localized, style: .default) { [weak self] _ in
            self?.battleStore?.acceptBattle(battleID: battleID) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        break // The PK request was accepted successfully; follow-up handling is performed via `BattleEvent`
                    case .failure(let error):
                        self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "coGuest.application.reject".localized, style: .cancel) { [weak self] _ in
            self?.battleStore?.rejectBattle(battleID: battleID) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        break // Rejected successfully
                    case .failure(let error):
                        self?.view.makeToast(String(format: "basicStreaming.status.failed".localized, error.message))
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Audience-side state observation

    /// Observe connection state changes on the audience side
    private func setupCoHostStateObserver() {
        coHostStore?.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                let wasConnected = self.isCoHostConnected
                self.isCoHostConnected = state.coHostStatus == .connected
                if wasConnected != self.isCoHostConnected {
                    self.updateConnectionStatus()
                }
            }
            .store(in: &cancellables)
    }

    /// Observe PK state changes on both the audience and host sides (score updates)
    private func setupBattleStateObserver() {
        battleStore?.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                if let battleInfo = state.currentBattleInfo {
                    if !self.isBattling {
                        self.handleBattleStarted(battleInfo: battleInfo, battleUsers: state.battleUsers)
                    } else if state.battleUsers.count != self.battleScoreEntries.count {
                        // Participant count changed (someone joined/left), rebuild the score panel
                        self.rebuildScoreViews(battleUsers: state.battleUsers)
                    }
                    // Update scores
                    self.updateBattleScores(state: state)
                } else if self.isBattling {
                    self.handleBattleEnded()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - PK State Handling

    /// PK started
    private func handleBattleStarted(battleInfo: BattleInfo, battleUsers: [SeatUserInfo]) {
        isBattling = true
        currentBattleID = battleInfo.battleID

        // Calculate the PK end time: prefer `endTime`, otherwise derive it from `startTime + duration`
        if battleInfo.endTime > 0 {
            pkEndTime = battleInfo.endTime
        } else if battleInfo.startTime > 0, battleInfo.config.duration > 0 {
            pkEndTime = battleInfo.startTime + UInt(battleInfo.config.duration)
        } else if battleInfo.config.duration > 0 {
            pkEndTime = UInt(Date().timeIntervalSince1970) + UInt(battleInfo.config.duration)
        } else {
            pkEndTime = 0
        }

        // Dynamically build the multi-user score panel
        rebuildScoreViews(battleUsers: battleUsers)

        // Show the PK score panel
        pkScoreView.isHidden = false

        // Update the PK button state (host side): gray background + semi-transparent text, indicating PK in progress
        if role == .anchor {
            battleButton.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
            battleButton.backgroundColor = .systemGray
        }

        // Start the countdown
        startPKTimer()

        view.makeToast("livePK.battle.started".localized)
    }

    /// PK ended
    private func handleBattleEnded() {
        // Prevent duplicate triggering
        guard isBattling else { return }
        isBattling = false
        stopPKTimer()

        // Show the result first, then hide the score panel
        showBattleResult()

        // Restore the PK button state (host side): red background + white text
        if role == .anchor {
            battleButton.setTitleColor(.white, for: .normal)
            battleButton.backgroundColor = UIColor.systemRed
            updateCoHostButtonState()
        }

        currentBattleID = nil
    }

    /// Update PK scores (supports multiple users)
    private func updateBattleScores(state: BattleState) {
        for (index, entry) in battleScoreEntries.enumerated() {
            let score = state.battleScore[entry.userID] ?? 0
            battleScoreEntries[index].score = score

            // Find the corresponding score label by tag and update it
            if let scoreLabel = scoreStackView.viewWithTag(100 + index) as? UILabel {
                scoreLabel.text = "\(score)"
            }
        }
    }

    /// Display the PK result (supports multiple users)
    private func showBattleResult() {
        // Find the current user's score and the highest score
        let myScore = battleScoreEntries.first(where: { $0.isMe })?.score ?? 0
        let maxScore = battleScoreEntries.map(\.score).max() ?? 0
        let maxCount = battleScoreEntries.filter { $0.score == maxScore }.count

        if maxCount == battleScoreEntries.count {
            // All users have the same score → draw
            pkStatusLabel.text = "livePK.battle.draw".localized
            pkStatusLabel.textColor = .white
        } else if myScore == maxScore {
            // The current user has the highest score → win
            pkStatusLabel.text = "livePK.battle.win".localized
            pkStatusLabel.textColor = .systemYellow
        } else {
            // The current user does not have the highest score → lose
            pkStatusLabel.text = "livePK.battle.lose".localized
            pkStatusLabel.textColor = .systemGray
        }

        // Highlight the score labels of the winners
        for (index, entry) in battleScoreEntries.enumerated() {
            if let scoreLabel = scoreStackView.viewWithTag(100 + index) as? UILabel {
                if entry.score == maxScore && maxCount < battleScoreEntries.count {
                    scoreLabel.textColor = .systemYellow
                }
            }
        }

        // Keep the score panel visible while displaying the result
        pkScoreView.isHidden = false

        // Hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self, !self.isBattling else { return }
            self.pkScoreView.isHidden = true
            self.pkStatusLabel.text = "livePK.status.battling".localized
            self.pkStatusLabel.textColor = .systemYellow
        }
    }

    // MARK: - PK Countdown

    private func startPKTimer() {
        stopPKTimer()
        print("[LivePK] startPKTimer - pkEndTime: \(pkEndTime), now: \(UInt(Date().timeIntervalSince1970))")
        updatePKTimerDisplay()
        pkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePKTimerDisplay()
        }
    }

    private func stopPKTimer() {
        pkTimer?.invalidate()
        pkTimer = nil
        pkTimerLabel.text = nil
    }

    private func updatePKTimerDisplay() {
        guard pkEndTime > 0 else {
            print("[LivePK] pkEndTime is 0, timer display skipped")
            pkTimerLabel.text = nil
            return
        }

        let now = UInt(Date().timeIntervalSince1970)
        print("[LivePK] Timer update - now: \(now), pkEndTime: \(pkEndTime)")

        if now >= pkEndTime {
            stopPKTimer()
            pkTimerLabel.text = "00:00"
            return
        }

        let remaining = pkEndTime - now
        let minutes = remaining / 60
        let seconds = remaining % 60
        pkTimerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - UI State Updates

    /// update the connection button state (differentiate it by icon and background color)
    private func updateCoHostButtonState() {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        if isCoHostConnected {
            // connected: disconnect icon + gray background
            coHostButton.setImage(UIImage(systemName: "link.badge.plus", withConfiguration: iconConfig), for: .normal)
            coHostButton.backgroundColor = UIColor.systemGreen
            coHostButton.tintColor = .white

            // Enable the PK button after connection
            battleButton.isEnabled = true
            battleButton.alpha = 1.0
        } else {
            // not connected: connection icon + orange background
            coHostButton.setImage(UIImage(systemName: "link", withConfiguration: iconConfig), for: .normal)
            coHostButton.backgroundColor = UIColor.systemOrange
            coHostButton.tintColor = .white

            // not connected PK buttondisabled
            battleButton.isEnabled = false
            battleButton.alpha = 0.5
        }
    }

    /// updateconnection stateindicator
    private func updateConnectionStatus() {
        if isBattling {
            connectionStatusLabel.text = "  \("livePK.status.battling".localized)  "
            connectionStatusLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
            connectionStatusLabel.isHidden = false
        } else if isCoHostConnected {
            connectionStatusLabel.text = "  \("livePK.status.coHostConnected".localized)  "
            connectionStatusLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.7)
            connectionStatusLabel.isHidden = false
        } else {
            connectionStatusLabel.isHidden = true
        }
    }

    // MARK: - State Handling

    private func handleLiveListEvent(_ event: LiveListEvent) {
        switch event {
        case .onLiveEnded(let endedLiveID, _, _):
            if endedLiveID == liveID && role == .audience {
                isLiveActive = false
                stopPKTimer()
                view.makeToast("basicStreaming.status.ended".localized) { [weak self] _ in
                    self?.navigationController?.popViewController(animated: true)
                }
            }

        case .onKickedOutOfLive(let kickedLiveID, _, _):
            if kickedLiveID == liveID {
                isLiveActive = false
                stopPKTimer()
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

    /// Update the navigation bar during the live session
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

        stopPKTimer()

        switch role {
        case .anchor:
            // exit the PK battle and the connection
            if isBattling, let battleID = currentBattleID {
                battleStore?.exitBattle(battleID: battleID) { result in
                    switch result {
                    case .success:
                        break
                    case .failure:
                        break
                    }
                }
            }
            if isCoHostConnected {
                coHostStore?.exitHostConnection { result in
                    switch result {
                    case .success:
                        break
                    case .failure:
                        break
                    }
                }
            }

            DeviceStore.shared.closeLocalCamera()
            DeviceStore.shared.closeLocalMicrophone()
            LiveListStore.shared.endLive { result in
                switch result {
                case .success:
                    break
                case .failure:
                    break
                }
            }

        case .audience:
            LiveListStore.shared.leaveLive { result in
                switch result {
                case .success:
                    break
                case .failure:
                    break
                }
            }
        }

        isLiveActive = false
    }
}

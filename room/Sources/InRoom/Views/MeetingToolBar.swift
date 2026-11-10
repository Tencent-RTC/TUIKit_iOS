import UIKit
import SnapKit
import Combine
import AtomicXCore

protocol MeetingToolBarTitleDisplaying: AnyObject {
    var showsTitle: Bool { get set }
}

protocol MeetingToolBarPopupItem: MeetingToolBarTitleDisplaying {
    var routerContext: RouterContext? { get set }
    var onRequestDismiss: (() -> Void)? { get set }
}

extension RoomScreenShareButton: MeetingToolBarPopupItem {}
extension RoomRecordingButton: MeetingToolBarPopupItem {}
extension RoomSettingsButton: MeetingToolBarPopupItem {}

final class MeetingToolBar: UIView {

    private static let maxButtonCount = 6
    private static let buttonSize: CGFloat = 44
    private static let menuColumnCount = 4
    private static let menuRowSpacing: CGFloat = 4
    private static let menuCellVerticalInset: CGFloat = 10
    private static let menuInsets = UIEdgeInsets(top: 6, left: 30, bottom: 14, right: 30)

    weak var routerContext: RouterContext? {
        didSet { wireFeatureButtons() }
    }

    private let roomID: String
    private let micButton: RoomMicButton
    private let camButton: RoomCameraButton
    private let speakerButton = RoomSpeakerButton()
    private let partButton: RoomParticipantButton
    private let screenShareButton: RoomScreenShareButton
    private let recordingButton: RoomRecordingButton
    private let settingsButton = RoomSettingsButton()

    private let stack = UIStackView()
    private let moreButton = UIControl()
    private let moreIconView = UIImageView()
    private var morePopup: RoomPopup?
    private var cancellableSet = Set<AnyCancellable>()

    private lazy var featureButtons: [UIView] = makeFeatureButtons()

    private var needsMoreButton: Bool {
        featureButtons.count > Self.maxButtonCount
    }

    private var visibleButtons: [UIView] {
        needsMoreButton ? Array(featureButtons.prefix(Self.maxButtonCount - 1)) : featureButtons
    }

    init(roomID: String) {
        self.roomID = roomID
        self.micButton = RoomMicButton(roomID: roomID)
        self.camButton = RoomCameraButton(roomID: roomID)
        self.partButton = RoomParticipantButton(roomID: roomID)
        self.screenShareButton = RoomScreenShareButton(roomID: roomID)
        self.recordingButton = RoomRecordingButton(roomID: roomID)
        super.init(frame: .zero)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(stack)
        moreButton.addSubview(moreIconView)
        applyButtons()
    }

    private func setupConstraints() {
        stack.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.height.equalTo(44)
        }
        moreIconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(20)
        }
    }

    private func setupStyles() {
        backgroundColor = .clear
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .equalSpacing
        moreButton.backgroundColor = UIColor.roomKitBgHover
        moreButton.layer.cornerRadius = 22
        moreButton.clipsToBounds = true
        moreIconView.image = RoomKitResources.image(named: "roomkit_icon_more")
        moreIconView.contentMode = .scaleAspectFit
        moreIconView.isUserInteractionEnabled = false
    }

    private func setupBindings() {
        moreButton.addTarget(self, action: #selector(handleMoreTap), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(moreTouchDown), for: .touchDown)
        moreButton.addTarget(self, action: #selector(moreTouchUp), for: [.touchUpOutside, .touchCancel])
        wireFeatureButtons()
        observeFeatureAvailability()
    }

    private func makeFeatureButtons() -> [UIView] {
        var buttons: [UIView] = [
            micButton,
            camButton,
            speakerButton,
            partButton,
            screenShareButton,
        ]
        if recordingButton.isAvailable { buttons.append(recordingButton) }
        buttons.append(settingsButton)
        return buttons
    }

    private func observeFeatureAvailability() {
        RoomParticipantStore.create(roomID: roomID).state
            .subscribe(StatePublisherSelector(projector: { $0.localParticipant?.role }))
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshFeatureButtons() }
            .store(in: &cancellableSet)
    }

    private func refreshFeatureButtons() {
        let next = makeFeatureButtons()
        let unchanged = next.count == featureButtons.count
            && zip(next, featureButtons).allSatisfy { $0 === $1 }
        guard !unchanged else { return }
        featureButtons = next
        applyButtons()
    }

    private func applyButtons() {
        dismissMorePopup()
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        var buttons = visibleButtons
        if needsMoreButton { buttons.append(moreButton) }
        buttons.forEach { $0.snp.removeConstraints() }
        buttons.forEach { addToStack($0) }
    }

    private func addToStack(_ button: UIView) {
        stack.addArrangedSubview(button)
        button.snp.makeConstraints { $0.size.equalTo(Self.buttonSize) }
    }

    private func wireFeatureButtons() {
        screenShareButton.routerContext = routerContext
        recordingButton.routerContext = routerContext
        settingsButton.routerContext = routerContext
        screenShareButton.onRequestDismiss = { [weak self] in self?.dismissMorePopup() }
        recordingButton.onRequestDismiss = { [weak self] in self?.dismissMorePopup() }
        settingsButton.onRequestDismiss = { [weak self] in self?.dismissMorePopup() }
    }
}

private extension MeetingToolBar {

    @objc func handleMoreTap() {
        moreTouchUp()
        guard morePopup == nil else { return }
        let items = makeOverflowItems()
        guard !items.isEmpty else { return }
        items.compactMap { $0 as? MeetingToolBarPopupItem }.forEach { item in
            item.routerContext = routerContext
            item.onRequestDismiss = { [weak self] in self?.dismissMorePopup() }
        }
        let grid = makeMoreMenuContent(items: items)
        let content = UIView()
        content.addSubview(grid)
        grid.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Self.menuInsets.top)
            $0.leading.equalToSuperview().offset(Self.menuInsets.left)
            $0.trailing.equalToSuperview().offset(-Self.menuInsets.right)
            $0.bottom.equalToSuperview().offset(-Self.menuInsets.bottom)
        }
        let popup = RoomPopup()
        popup.contentView.addSubview(content)
        content.snp.makeConstraints { $0.edges.equalToSuperview() }
        popup.contentView.snp.makeConstraints {
            $0.height.equalTo(menuHeight(for: items))
        }
        popup.onDismiss = { [weak self] _ in self?.morePopup = nil }
        morePopup = popup
        popup.show(in: self)
    }

    private func menuHeight(for items: [UIView]) -> CGFloat {
        let heights = items.map { $0.intrinsicContentSize.height }.filter { $0 > 0 }
        let cellHeight = (heights.max() ?? Self.buttonSize) + Self.menuCellVerticalInset * 2
        let rowCount = (items.count + Self.menuColumnCount - 1) / Self.menuColumnCount
        let rows = CGFloat(rowCount) * cellHeight
            + CGFloat(max(rowCount - 1, 0)) * Self.menuRowSpacing
        return ceil(rows + Self.menuInsets.top + Self.menuInsets.bottom)
    }

    private func makeOverflowItems() -> [UIView] {
        guard needsMoreButton else { return [] }
        var items: [UIView] = []
        if recordingButton.isAvailable {
            items.append(RoomRecordingButton(roomID: roomID))
        }
        items.append(RoomSettingsButton())
        return items
    }

    private func makeMoreMenuContent(items: [UIView]) -> UIView {
        let grid = UIStackView()
        grid.axis = .vertical
        grid.alignment = .fill
        grid.spacing = Self.menuRowSpacing
        items.forEach { ($0 as? MeetingToolBarTitleDisplaying)?.showsTitle = true }
        var index = 0
        while index < items.count {
            let rowItems = Array(items[index..<min(index + Self.menuColumnCount, items.count)])
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .top
            row.distribution = .fillEqually
            rowItems.forEach { item in
                let cell = UIView()
                cell.addSubview(item)
                item.snp.makeConstraints {
                    $0.top.equalToSuperview().offset(Self.menuCellVerticalInset)
                    $0.bottom.equalToSuperview().offset(-Self.menuCellVerticalInset)
                    $0.leading.equalToSuperview().offset(2)
                    $0.trailing.lessThanOrEqualToSuperview().offset(-2)
                    $0.width.equalTo(item.intrinsicContentSize.width)
                }
                row.addArrangedSubview(cell)
            }
            for _ in rowItems.count..<Self.menuColumnCount {
                row.addArrangedSubview(UIView())
            }
            grid.addArrangedSubview(row)
            index += Self.menuColumnCount
        }
        return grid
    }

    private func dismissMorePopup() {
        morePopup?.dismiss()
        morePopup = nil
    }

    @objc func moreTouchDown() {
        moreButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
    }

    @objc func moreTouchUp() {
        moreButton.transform = .identity
    }
}

import UIKit
import SnapKit

final class RoomAudioRouteSheet: UIView {

    var onSelect: ((RoomAudioOutput) -> Void)?
    var onDismiss: (() -> Void)?

    private weak var popup: RoomPopup?
    private let routeGroup = UIView()
    private let routeStack = UIStackView()
    private let routeRows: [RoomAudioRouteRow]
    private let cancelButton = UIButton(type: .custom)

    init(current: RoomAudioOutput) {
        routeRows = [
            RoomAudioRouteRow(output: .speaker, icon: "roomkit_icon_speaker", title: .audioSpeaker),
            RoomAudioRouteRow(output: .earpiece, icon: "roomkit_icon_earpiece", title: .audioEarpiece),
        ]
        super.init(frame: .zero)
        routeRows.forEach { $0.isCurrent = $0.output == current }
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            applyTheme()
        }
    }

    private func setupViews() {
        addSubview(routeGroup)
        routeGroup.addSubview(routeStack)
        addSubview(cancelButton)
        routeRows.forEach { routeStack.addArrangedSubview($0) }
    }

    private func setupConstraints() {
        routeGroup.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
        routeStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(6) }
        cancelButton.snp.makeConstraints {
            $0.top.equalTo(routeGroup.snp.bottom).offset(8)
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.bottom.equalToSuperview().offset(-12)
            $0.height.equalTo(48)
        }
    }

    private func setupStyles() {
        routeGroup.layer.cornerRadius = 16
        routeStack.axis = .vertical
        routeStack.spacing = 2

        cancelButton.layer.cornerRadius = 12
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15)
        cancelButton.setTitle(RoomKitResources.localizedString("roomkit.common.cancel"), for: .normal)

        applyTheme()
    }

    private func setupBindings() {
        routeRows.forEach { $0.addTarget(self, action: #selector(handleRowTap(_:)), for: .touchUpInside) }
        cancelButton.addTarget(self, action: #selector(handleCancelTap), for: .touchUpInside)
    }

    private func applyTheme() {
        routeGroup.backgroundColor = UIColor.roomKitBgCanvas
        cancelButton.backgroundColor = UIColor.roomKitBgCanvas
        cancelButton.setTitleColor(UIColor.roomKitFgPrimary, for: .normal)
    }
}

// MARK: - public methods

extension RoomAudioRouteSheet {

    func show(in host: UIView) {
        guard popup == nil else { return }
        let popup = RoomPopup()
        popup.contentView.addSubview(self)
        snp.remakeConstraints { $0.edges.equalToSuperview() }
        popup.onDismiss = { [weak self] _ in self?.onDismiss?() }
        self.popup = popup
        popup.show(in: host)
    }
}

// MARK: - private methods

extension RoomAudioRouteSheet {

    @objc private func handleRowTap(_ row: RoomAudioRouteRow) {
        let output = row.output
        let action = onSelect
        popup?.dismiss { action?(output) }
    }

    @objc private func handleCancelTap() {
        let action = onDismiss
        popup?.dismiss { action?() }
    }
}

// MARK: - localized strings

extension String {
    fileprivate static var audioSpeaker: String { RoomKitResources.localizedString("roomkit.main.audio_route_speaker") }
    fileprivate static var audioEarpiece: String { RoomKitResources.localizedString("roomkit.main.audio_route_earpiece") }
}

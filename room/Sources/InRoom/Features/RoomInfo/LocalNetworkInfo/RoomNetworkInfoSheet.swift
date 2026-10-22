import UIKit
import SnapKit
import Combine
import AtomicXCore

///
final class RoomNetworkInfoSheet: UIView {

    var onDismiss: (() -> Void)?

    private var cancellableSet = Set<AnyCancellable>()
    private weak var popup: RoomPopup?

    private let statusTitleLabel = UILabel()
    private let latencyMetric = RoomNetworkMetricView(icon: nil, label: .networkLatency, unit: "ms")
    private let upLossMetric = RoomNetworkMetricView(icon: "roomkit_icon_dir_up_tertiary", label: .networkPacketLoss, unit: "%")
    private let downLossMetric = RoomNetworkMetricView(icon: "roomkit_icon_dir_down_tertiary", label: .networkPacketLoss, unit: "%")
    private let deviceStore = DeviceStore.shared

    override init(frame: CGRect) {
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
        addSubview(statusTitleLabel)
        addSubview(latencyMetric)
        addSubview(upLossMetric)
        addSubview(downLossMetric)
    }

    private func setupConstraints() {
        statusTitleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        let stack = UIStackView(arrangedSubviews: [latencyMetric, upLossMetric, downLossMetric])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalTo(statusTitleLabel.snp.bottom).offset(10)
            $0.leading.trailing.equalToSuperview().inset(16)
            $0.bottom.equalToSuperview().offset(-20)
        }
    }

    private func setupStyles() {
        statusTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusTitleLabel.textColor = UIColor.roomKitFgPrimary
    }

    private func setupBindings() {
        deviceStore.state.subscribe()
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.render(info: state.networkInfo)
            }
            .store(in: &cancellableSet)
        render(info: deviceStore.state.value.networkInfo)
    }

    // MARK: - private methods

    private func render(info: NetworkInfo) {
        switch info.quality {
        case .excellent, .good:
            statusTitleLabel.text = .networkGood
        case .poor:
            statusTitleLabel.text = .networkFair
        case .bad, .veryBad:
            statusTitleLabel.text = .networkWeak
        case .down, .unknown:
            statusTitleLabel.text = .networkDisconnected
        }
        latencyMetric.set(value: Int(info.delay), level: level(delay: Int(info.delay)))
        upLossMetric.set(value: Int(info.upLoss), level: level(loss: Int(info.upLoss)))
        downLossMetric.set(value: Int(info.downLoss), level: level(loss: Int(info.downLoss)))
    }

    private func level(delay: Int) -> Int {
        if delay >= Self.DELAY_BAD { return 2 }
        if delay >= Self.DELAY_WARN { return 1 }
        return 0
    }

    private func level(loss: Int) -> Int {
        if loss >= Self.LOSS_BAD { return 2 }
        if loss >= Self.LOSS_WARN { return 1 }
        return 0
    }
}

// MARK: - private constants

private extension RoomNetworkInfoSheet {
    static let DELAY_WARN = 100
    static let DELAY_BAD = 200
    static let LOSS_WARN = 2
    static let LOSS_BAD = 8
}

// MARK: - public methods

extension RoomNetworkInfoSheet {

    func show(in host: UIView) {
        guard popup == nil else { return }
        let popup = RoomPopup()
        popup.contentView.addSubview(self)
        snp.makeConstraints { $0.edges.equalToSuperview() }
        popup.onDismiss = { [weak self] _ in
            self?.popup = nil
            self?.onDismiss?()
        }
        self.popup = popup
        popup.show(in: host)
    }
}


private final class RoomNetworkMetricView: UIView {

    private let iconView = UIImageView()
    private let label = UILabel()
    private let valueLabel = UILabel()
    private let unitLabel = UILabel()
    private var title: String

    init(icon: String?, label title: String, unit: String) {
        self.title = title
        super.init(frame: .zero)
        if let icon {
            iconView.image = RoomKitResources.image(named: icon)
            iconView.contentMode = .scaleAspectFit
            iconView.alpha = 0.72
        }
        label.text = title
        label.font = .systemFont(ofSize: 10)
        label.textColor = UIColor.roomKitFgTertiary
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        unitLabel.text = unit
        unitLabel.font = .systemFont(ofSize: 10, weight: .medium)
        unitLabel.textColor = UIColor.roomKitFgSecondary

        let head = UIStackView(arrangedSubviews: icon == nil ? [label] : [iconView, label])
        head.axis = .horizontal
        head.spacing = 2
        head.alignment = .center
        let valueRow = UIStackView(arrangedSubviews: [valueLabel, unitLabel])
        valueRow.axis = .horizontal
        valueRow.spacing = 2
        valueRow.alignment = .firstBaseline
        addSubview(head)
        addSubview(valueRow)
        head.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.leading.trailing.equalToSuperview().inset(8)
        }
        iconView.snp.makeConstraints { $0.size.equalTo(8) }
        valueRow.snp.makeConstraints {
            $0.top.equalTo(head.snp.bottom).offset(1)
            $0.leading.equalToSuperview().offset(8)
            $0.trailing.lessThanOrEqualToSuperview().offset(-8)
            $0.bottom.equalToSuperview().offset(-10)
        }
        layer.cornerRadius = 8
        backgroundColor = UIColor.roomKitBgHover
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(value: Int, level: Int) {
        valueLabel.text = "\(value)"
        valueLabel.textColor = level == 2 ? UIColor.roomKitDanger : (level == 1 ? UIColor.roomKitWarning : UIColor.roomKitFgPrimary)
    }
}

// MARK: - localized strings

private extension String {
    static var networkGood: String { RoomKitResources.localizedString("roomkit.network.good") }
    static var networkFair: String { RoomKitResources.localizedString("roomkit.network.fair") }
    static var networkWeak: String { RoomKitResources.localizedString("roomkit.network.weak") }
    static var networkDisconnected: String { RoomKitResources.localizedString("roomkit.network.disconnected") }
    static var networkLatency: String { RoomKitResources.localizedString("roomkit.network.latency") }
    static var networkPacketLoss: String { RoomKitResources.localizedString("roomkit.network.packet_loss") }
}

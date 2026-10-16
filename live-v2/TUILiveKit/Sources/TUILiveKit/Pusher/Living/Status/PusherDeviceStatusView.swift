import UIKit
import AtomicXCore
import SnapKit

final class PusherDeviceStatusView: UIView {
    struct Presentation: Equatable {
        let videoQuality: PusherVideoQualitySetting
        let isMuted: Bool
        let captureVolume: Int
        let status: PusherDeviceStatusState
    }

    var onContentHeightChanged: ((CGFloat) -> Void)?
    private var streamTopConstraint: Constraint?
    private var reportedHeight: CGFloat = 0
    var onSetCaptureVolume: ((Int) -> Void)?

    private let videoRow = DeviceStatusRowView(icon: "livekit_status_video", title: LiveKitResources.localizedString("tuilivekit.pusher.status.video.normal.title"), detail: LiveKitResources.localizedString("tuilivekit.pusher.status.video.normal.detail"))
    private let audioRow = DeviceStatusRowView(icon: "livekit_status_audio", title: LiveKitResources.localizedString("tuilivekit.pusher.status.audio.normal.title"), detail: LiveKitResources.localizedString("tuilivekit.pusher.status.audio.normal.detail"))
    private let temperatureRow = DeviceStatusRowView(icon: "livekit_status_temperature", title: LiveKitResources.localizedString("tuilivekit.pusher.status.temperature.normal.title"), detail: LiveKitResources.localizedString("tuilivekit.pusher.status.temperature.normal.detail"))
    private let networkRow = DeviceStatusRowView(icon: "livekit_status_network", title: LiveKitResources.localizedFormat("tuilivekit.pusher.status.network.title", LiveKitResources.localizedString("tuilivekit.pusher.status.network.wifi"), LiveKitResources.localizedString("tuilivekit.pusher.status.network.excellent")), detail: LiveKitResources.localizedString("tuilivekit.pusher.status.network.keep"))
    private let videoResolutionLabel = LiveText(.caption, tone: .tertiary, alignment: .right)
    private let volumeSlider = LiveSlider(range: 0 ... 100)
    private let volumeLabel = LiveText(.control, tone: .tertiary, alignment: .right)
    private let networkCard = NetworkStatisticsCardView(values: ["-", "-", "-"], titles: [
        LiveKitResources.localizedString("tuilivekit.pusher.status.rtt"),
        LiveKitResources.localizedString("tuilivekit.pusher.status.down_loss"),
        LiveKitResources.localizedString("tuilivekit.pusher.status.up_loss"),
    ])
    private let streamInformationCard = UIView()
    private let videoInfoColumn = StreamInformationColumnView(titleKey: "video_info", fieldsKey: "video_fields", fieldWidth: 55, valueSpacing: 8, valueLines: 3)
    private let audioInfoColumn = StreamInformationColumnView(titleKey: "audio_info", fieldsKey: "audio_fields", fieldWidth: 52, valueSpacing: 7, valueLines: 2)
    private var separators: [UIView] = []
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        guard width > 0 else { return }
        let rowWidth = max(0, width - 42)
        var top: CGFloat = 14
        let rows = [videoRow, audioRow, temperatureRow, networkRow]
        for (index, row) in rows.enumerated() {
            let height = row.preferredHeight(width: rowWidth)
            row.frame = CGRect(x: 21, y: top, width: rowWidth, height: height)
            if index == 0 {
                videoResolutionLabel.frame = CGRect(x: width - 72, y: top + 2, width: 49, height: 16)
            }
            top += height + (index == 1 ? 0 : 12)
            if index == 1 {
                volumeSlider.frame = CGRect(x: 64, y: top, width: max(0, width - 128), height: 23)
                volumeLabel.frame = CGRect(x: width - 51, y: top + 3, width: 28, height: 15)
                top += 35
            }
            if index < separators.count {
                separators[index].frame = CGRect(x: 21, y: top, width: rowWidth, height: 1 / UIScreen.main.scale)
                top += 12
            }
        }
        let cardWidth = max(0, width - 36)
        let networkHeight = networkCard.preferredHeight(width: cardWidth)
        networkCard.frame = CGRect(x: 18, y: top, width: cardWidth, height: networkHeight)
        let streamTop = top + networkHeight + 9
        streamTopConstraint?.update(offset: streamTop)
        let contentHeight = streamTop + 112 + max(26, safeAreaInsets.bottom)
        if reportedHeight != contentHeight {
            reportedHeight = contentHeight
            onContentHeightChanged?(contentHeight)
        }
    }

    func bind(_ presentation: Presentation) {
        let status = presentation.status
        videoResolutionLabel.text = status.hasAVStatistics && status.videoWidth > 0
            ? "\(status.videoWidth)P"
            : "--"
        videoRow.set(.video(status.videoStatus))
        let audioStatus: PusherDeviceStatusState.MediaStatus =
            presentation.isMuted || presentation.captureVolume == 0 ? .off : status.audioStatus
        audioRow.set(.audio(audioStatus))
        temperatureRow.set(.temperature(status.temperatureStatus))
        networkRow.set(.network(status))
        networkCard.setValues([
            "\(status.delay)ms",
            "\(status.downLoss)%",
            "\(status.upLoss)%",
        ])
        videoInfoColumn.setValue(status.videoInformation)
        audioInfoColumn.setValue(status.audioInformation)
        let captureVolume = min(max(presentation.captureVolume, 0), 100)
        volumeSlider.value = Float(captureVolume)
        volumeLabel.text = String(captureVolume)
        setNeedsLayout()
    }

    private func configureUI() {
        videoRow.titleTrailingInset = 57
        [videoRow, audioRow, temperatureRow, networkRow, videoResolutionLabel, volumeSlider, volumeLabel, networkCard, streamInformationCard].forEach(addSubview)
        volumeSlider.accessibilityLabel = LiveKitResources.localizedString("tuilivekit.pusher.status.voice_volume")
        volumeSlider.onValueChanged = { [weak self] value in self?.volumeChanged(Int(value)) }
        separators = (0 ..< 3).map { _ in
            let view = UIView()
            view.backgroundColor = PusherLiveStatusContentStyle.separator
            addSubview(view)
            return view
        }
        PusherLiveStatusContentStyle.applyCardStyle(streamInformationCard, radius: 15)
        configureStreamInformationCard()
    }

    private func volumeChanged(_ value: Int) {
        volumeLabel.text = String(value)
        onSetCaptureVolume?(value)
    }

    private func configureStreamInformationCard() {
        // Resolve the card width in the same layout pass as its constrained columns.
        // A frame assigned in layoutSubviews leaves a temporary zero-width parent.
        streamInformationCard.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(18)
            streamTopConstraint = make.top.equalToSuperview().offset(377).constraint
            make.height.equalTo(112)
        }
        [videoInfoColumn, audioInfoColumn].forEach(streamInformationCard.addSubview)
        videoInfoColumn.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(15)
            make.top.bottom.equalToSuperview()
        }
        audioInfoColumn.snp.makeConstraints { make in
            make.leading.equalTo(videoInfoColumn.snp.trailing).offset(14)
            make.trailing.equalToSuperview().inset(15)
            make.top.bottom.width.equalTo(videoInfoColumn)
        }
    }
}

struct PusherDeviceStatusState: Equatable {
    enum MediaStatus: Equatable {
        case normal
        case off
        case deviceError
        case streamError
    }

    enum TemperatureStatus: Equatable {
        case normal
        case fair
        case serious
    }

    enum NetworkKind: Equatable {
        case unknown
        case wifi
        case cellular
    }

    var temperatureStatus: TemperatureStatus = .normal
    var networkKind: NetworkKind = .unknown
    var networkQuality: UInt = 0
    var delay: UInt32 = 0
    var downLoss: UInt32 = 0
    var upLoss: UInt32 = 0
    var videoBitrate: UInt = 0
    var videoWidth = 0
    var videoHeight = 0
    var frameRate: UInt = 0
    var audioSampleRate: UInt = 0
    var audioBitrate: UInt = 0
    var hasAVStatistics = false
    var cameraStatus: DeviceStatus = .off
    var microphoneStatus: DeviceStatus = .off
    var cameraError: DeviceError = .noError
    var microphoneError: DeviceError = .noError
    var videoQuality: VideoQuality = .quality720P
}

extension PusherDeviceStatusState {
    var videoStatus: MediaStatus {
        let isAbnormal = networkIsDown || (hasAVStatistics && frameRate < 15)
        return Self.mediaStatus(cameraStatus, error: cameraError, streamIsAbnormal: isAbnormal)
    }

    var audioStatus: MediaStatus {
        let isAbnormal = hasAVStatistics && (audioSampleRate == 0 || audioBitrate == 0)
        return Self.mediaStatus(microphoneStatus, error: microphoneError, streamIsAbnormal: isAbnormal)
    }

    private var networkIsDown: Bool {
        networkQuality == NetworkQuality.down.rawValue
    }

    private static func mediaStatus(
        _ status: DeviceStatus,
        error: DeviceError,
        streamIsAbnormal: Bool
    ) -> MediaStatus {
        guard error == .noError else { return .deviceError }
        guard status == .on else { return .off }
        guard !streamIsAbnormal else { return .streamError }
        return .normal
    }

}

private final class StreamInformationColumnView: UIView {
    private let valueLabel = LiveText(.metadata, tone: .secondary)

    init(titleKey: String, fieldsKey: String, fieldWidth: CGFloat, valueSpacing: CGFloat, valueLines: Int) {
        super.init(frame: .zero)
        let prefix = "tuilivekit.pusher.status."
        let titleLabel = LiveText(.sectionTitle, text: LiveKitResources.localizedString(prefix + titleKey), tone: .secondary)
        let fieldsLabel = LiveText(.metadata, tone: .disabled)
        titleLabel.textColor = DeviceStatusStyle.fieldTitle
        fieldsLabel.textColor = DeviceStatusStyle.fieldDescription
        valueLabel.textColor = DeviceStatusStyle.fieldValue
        fieldsLabel.adjustsFontSizeToFitWidth = true
        fieldsLabel.minimumScaleFactor = 0.75
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        fieldsLabel.numberOfLines = valueLines
        fieldsLabel.setText(LiveKitResources.localizedString(prefix + fieldsKey), lineHeight: 19)
        valueLabel.numberOfLines = valueLines
        [titleLabel, fieldsLabel, valueLabel].forEach(addSubview)

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(14)
            make.height.equalTo(16)
        }
        fieldsLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview().offset(44)
            make.width.equalTo(max(fieldWidth, ceil(fieldsLabel.intrinsicContentSize.width)))
            make.height.equalTo(valueLines * 19)
        }
        valueLabel.snp.makeConstraints { make in
            make.leading.equalTo(fieldsLabel.snp.trailing).offset(valueSpacing)
            make.trailing.equalToSuperview()
            make.top.height.equalTo(fieldsLabel)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValue(_ value: String) {
        valueLabel.setText(value, lineHeight: 19)
    }
}

private final class DeviceStatusRowView: UIView {
    var titleTrailingInset: CGFloat = 0
    private let iconView = UIImageView()
    private let titleLabel = LiveText(.body, tone: .secondary, emphasized: true)
    private let detailLabel = LiveText(.control, tone: .disabled)
    private let defaultIcon: String

    init(icon: String, title: String, detail: String) {
        defaultIcon = icon
        super.init(frame: .zero)
        iconView.image = LiveKitResources.image(named: icon)?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = .liveStatusNormal
        addSubview(iconView)
        titleLabel.text = title
        addSubview(titleLabel)
        detailLabel.text = detail
        titleLabel.numberOfLines = 0
        detailLabel.numberOfLines = 0
        addSubview(detailLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        iconView.frame = CGRect(x: 0, y: 4, width: 30, height: 30)
        let titleWidth = max(0, bounds.width - 43 - titleTrailingInset)
        let titleHeight = ceil(titleLabel.sizeThatFits(CGSize(width: titleWidth, height: .greatestFiniteMagnitude)).height)
        titleLabel.frame = CGRect(x: 43, y: 0, width: titleWidth, height: titleHeight)
        detailLabel.frame = CGRect(x: 43, y: titleHeight + 4, width: max(0, bounds.width - 43), height: max(0, bounds.height - titleHeight - 4))
    }

    func preferredHeight(width: CGFloat) -> CGFloat {
        let titleSize = titleLabel.sizeThatFits(CGSize(width: max(1, width - 43 - titleTrailingInset), height: .greatestFiniteMagnitude))
        let detailSize = detailLabel.sizeThatFits(CGSize(width: max(1, width - 43), height: .greatestFiniteMagnitude))
        return max(42, ceil(titleSize.height) + 4 + ceil(detailSize.height))
    }

    func set(_ presentation: DeviceStatusRowModel) {
        titleLabel.text = presentation.title
        detailLabel.text = presentation.detail
        let image = LiveKitResources.image(named: presentation.icon ?? defaultIcon)
        iconView.image = image?.withRenderingMode(presentation.usesOriginalColors ? .alwaysOriginal : .alwaysTemplate)
        iconView.tintColor = presentation.tintColor
        setNeedsLayout()
    }
}

private final class NetworkStatisticsCardView: UIView {
    private var valueLabels: [UILabel] = []
    private var titleLabels: [UILabel] = []

    init(values: [String], titles: [String]) {
        super.init(frame: .zero)
        PusherLiveStatusContentStyle.applyCardStyle(self, radius: 15)
        for (value, title) in zip(values, titles) {
            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.textColor = .liveStatusNormal
            valueLabel.font = NetworkStatisticsCardViewTypography.valueFont
            valueLabel.textAlignment = .center
            let titleLabel = LiveText(.metadata, text: title, tone: .tertiary, alignment: .center)
            titleLabel.textColor = DeviceStatusStyle.metricTitle
            titleLabel.numberOfLines = 2
            addSubview(valueLabel); addSubview(titleLabel)
            valueLabels.append(valueLabel); titleLabels.append(titleLabel)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let columnWidth = bounds.width / 3
        for index in valueLabels.indices {
            valueLabels[index].frame = CGRect(x: CGFloat(index) * columnWidth, y: 11, width: columnWidth, height: 25)
            titleLabels[index].frame = CGRect(x: CGFloat(index) * columnWidth, y: 42, width: columnWidth, height: max(14, bounds.height - 54))
        }
    }

    func preferredHeight(width: CGFloat) -> CGFloat {
        let columnWidth = max(1, width / 3)
        let titleHeight = titleLabels.map {
            ceil($0.sizeThatFits(CGSize(width: columnWidth, height: .greatestFiniteMagnitude)).height)
        }.max() ?? 14
        return 42 + max(14, titleHeight) + 12
    }

    func setValues(_ values: [String]) {
        for (label, value) in zip(valueLabels, values) {
            label.text = value
        }
    }
}

private extension PusherDeviceStatusState {
    var videoInformation: String {
        guard hasAVStatistics else { return "--\n--\n--" }
        let resolution = videoWidth > 0 && videoHeight > 0 ? "\(videoWidth)×\(videoHeight)" : "--"
        let bitrate = videoBitrate > 0 ? "\(videoBitrate) kbps" : "--"
        let fps = frameRate > 0 ? "\(frameRate) FPS" : "--"
        return "\(resolution)\n\(bitrate)\n\(fps)"
    }

    var audioInformation: String {
        guard hasAVStatistics else { return "--\n--" }
        let sampleRate = audioSampleRate > 0 ? "\(audioSampleRate) Hz" : "--"
        let bitrate = audioBitrate > 0 ? "\(audioBitrate) kbps" : "--"
        return "\(sampleRate)\n\(bitrate)"
    }
}

private enum MediaKind: String {
    case video
    case audio
}

private struct DeviceStatusRowModel {
    let title: String
    let detail: String
    let tintColor: UIColor
    var icon: String?
    var usesOriginalColors = false

    static func video(_ status: PusherDeviceStatusState.MediaStatus) -> Self {
        switch status {
        case .normal:      return media(.video, titleKey: "normal", detailKey: "normal", color: .liveStatusNormal)
        case .off:         return media(.video, titleKey: "off", detailKey: "off", color: .liveStatusWarning)
        case .deviceError: return media(.video, titleKey: "error", detailKey: "device_error", color: .liveStatusWarning)
        case .streamError: return media(.video, titleKey: "error", detailKey: "stream_error", color: .liveStatusCritical)
        }
    }

    static func audio(_ status: PusherDeviceStatusState.MediaStatus) -> Self {
        switch status {
        case .normal:      return media(.audio, titleKey: "normal", detailKey: "normal", color: .liveStatusNormal)
        case .off:         return media(.audio, titleKey: "off", detailKey: "off", color: .liveStatusWarning)
        case .deviceError: return media(.audio, titleKey: "error", detailKey: "device_error", color: .liveStatusWarning)
        case .streamError: return media(.audio, titleKey: "error", detailKey: "stream_error", color: .liveStatusCritical)
        }
    }

    private static func media(
        _ kind: MediaKind,
        titleKey: String,
        detailKey: String,
        color: UIColor
    ) -> Self {
        Self(
            title: localized("\(kind.rawValue).\(titleKey).title"),
            detail: localized("\(kind.rawValue).\(detailKey).detail"),
            tintColor: color
        )
    }

    static func temperature(_ status: PusherDeviceStatusState.TemperatureStatus) -> Self {
        let key: String
        let tintColor: UIColor
        switch status {
        case .normal: (key, tintColor) = ("normal", .liveStatusNormal)
        case .fair: (key, tintColor) = ("fair", .liveStatusWarning)
        case .serious: (key, tintColor) = ("serious", .liveStatusCritical)
        }
        return Self(
            title: localized("temperature.\(key).title"),
            detail: localized("temperature.\(key).detail"),
            tintColor: tintColor
        )
    }

    static func network(_ status: PusherDeviceStatusState) -> Self {
        let kind: String
        switch status.networkKind {
        case .wifi: kind = localized("network.wifi")
        case .cellular: kind = localized("network.cellular")
        case .unknown: kind = localized("network.unknown")
        }
        let content: (quality: String, detail: String, color: UIColor, icon: String?)
        switch status.networkQuality {
        case 1: content = ("network.excellent", "network.keep", .liveStatusNormal, nil)
        case 2: content = ("network.good", "network.keep", .liveStatusNormal, nil)
        case 3: content = ("network.poor", "network.fluctuating", .liveStatusWarning, "livekit_status_network_poor")
        case 4: content = ("network.bad", "network.switch", .liveStatusCritical, "livekit_status_network_bad")
        case 5: content = ("network.very_bad", "network.switch", .liveStatusCritical, "livekit_status_network_bad")
        case 6: content = ("network.disconnected", "network.disconnected_detail", .liveStatusCritical, "livekit_status_network_down")
        default: content = ("network.checking", "network.checking_detail", .liveStatusUnknown, nil)
        }
        return Self(
            title: LiveKitResources.localizedFormat("tuilivekit.pusher.status.network.title", kind, localized(content.quality)),
            detail: localized(content.detail),
            tintColor: content.color,
            icon: content.icon,
            usesOriginalColors: content.icon != nil
        )
    }

    private static func localized(_ suffix: String) -> String {
        LiveKitResources.localizedString("tuilivekit.pusher.status.\(suffix)")
    }
}

private extension UIColor {
    static let liveStatusNormal = LiveTheme.Color.brandBlue
    static let liveStatusWarning = UIColor(red: 1, green: 0.54, blue: 0.24, alpha: 1)
    static let liveStatusCritical = UIColor(red: 1, green: 0.36, blue: 0.38, alpha: 1)
    static let liveStatusUnknown = UIColor(red: 0.54, green: 0.58, blue: 0.66, alpha: 1)
}

private enum DeviceStatusStyle {
    static let fieldTitle: UIColor = UIColor.white.withAlphaComponent(0.82)
    static let fieldDescription: UIColor = UIColor.white.withAlphaComponent(0.34)
    static let fieldValue: UIColor = UIColor.white.withAlphaComponent(0.68)
    static let metricTitle: UIColor = UIColor.white.withAlphaComponent(0.42)
}

private enum NetworkStatisticsCardViewTypography {
    static let valueFont: UIFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
}

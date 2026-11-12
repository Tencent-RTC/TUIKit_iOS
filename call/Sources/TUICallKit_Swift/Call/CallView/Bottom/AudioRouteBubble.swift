import AtomicXCore
import AVFAudio
import SnapKit
import UIKit

enum CallAudioRouteKind {
    static func isBluetooth(deviceId: String, outputs: [AVAudioSessionPortDescription]) -> Bool {
        guard let port = outputs.first(where: { $0.uid == deviceId }) else { return false }
        return [.bluetoothHFP, .bluetoothA2DP, .bluetoothLE].contains(port.portType)
    }
}

final class AudioRouteBubble: CallKitBubble {

    var onSelect: ((DeviceInfo) -> Void)?

    func reload(devices: [DeviceInfo], current: DeviceInfo?) {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for device in devices {
            stackView.addArrangedSubview(makeRow(device: device, isCurrent: device.deviceId == current?.deviceId, outputs: outputs))
        }
    }

    private func makeRow(device: DeviceInfo, isCurrent: Bool, outputs: [AVAudioSessionPortDescription]) -> UIView {
        let row = UIControl()
        let display = Self.display(for: device, outputs: outputs)
        let icon = UIImageView(image: CallKitResources.image(named: display.icon)?.withRenderingMode(.alwaysTemplate))
        icon.tintColor = isCurrent ? CallKitTheme.brandText : .white
        icon.contentMode = .scaleAspectFit
        icon.snp.makeConstraints { make in
            make.size.equalTo(20)
        }

        let label = UILabel()
        label.text = display.title
        label.font = .systemFont(ofSize: 15)
        label.textColor = isCurrent ? CallKitTheme.brandText : .white
        label.numberOfLines = 0

        let check = CallKitCheckLabel(tint: CallKitTheme.brandText)
        check.isHidden = !isCurrent

        let rowStack = UIStackView(arrangedSubviews: [icon, label, check])
        rowStack.spacing = 12
        rowStack.alignment = .center
        rowStack.isUserInteractionEnabled = false
        row.addSubview(rowStack)
        rowStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 18, bottom: 12, right: 18))
        }
        row.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(52)
        }
        row.addAction(UIAction { [weak self] _ in self?.onSelect?(device) }, for: .touchUpInside)
        return row
    }

    private static func display(for device: DeviceInfo, outputs: [AVAudioSessionPortDescription]) -> (title: String, icon: String) {
        switch device.deviceName {
        case "speakerphone": return (CallKitResources.text("callkit.route.speaker"), "callkit_icon_speaker")
        case "earpiece": return (CallKitResources.text("callkit.route.earpiece"), "callkit_icon_phone")
        default:
            let isBluetooth = CallAudioRouteKind.isBluetooth(deviceId: device.deviceId, outputs: outputs)
            return (device.deviceName, isBluetooth ? "callkit_icon_bluetooth" : "callkit_icon_phone")
        }
    }
}

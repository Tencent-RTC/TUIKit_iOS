import SnapKit
import UIKit

final class VoiceLoungePrepareMorePanel: BottomSheetView {
    var onLayout: (() -> Void)?
    var onTranscriber: (() -> Void)?
    var onAudio: (() -> Void)?

    private let grid = UIStackView()

    override var sheetHeight: CGFloat { PrepareToolStyle.sheetHeight }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    private func setupViews() {
        contentView.addSubview(grid)
        let items: [(String, PrepareToolIcon, () -> Void)] = [
            ("tuilivekit.voiceroom.prepare.more_layout", .layout, { [weak self] in self?.onLayout?() }),
            ("tuilivekit.voiceroom.prepare.more_caption", .transcriber, { [weak self] in self?.onTranscriber?() }),
            ("tuilivekit.voiceroom.prepare.more_audio", .audio, { [weak self] in self?.onAudio?() }),
        ]
        items.forEach { key, icon, action in
            let item = ToolButton(titleKey: key, icon: icon)
            item.onTap = { [weak self] in
                self?.dismiss()
                action()
            }
            grid.addArrangedSubview(item)
        }
    }

    private func setupConstraints() {
        grid.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(PrepareToolStyle.gridInset)
            make.top.equalToSuperview().offset(PrepareToolStyle.gridTop)
        }
    }

    private func setupStyles() {
        sheetTitle = .moreTitle
        grid.axis = .horizontal
        grid.distribution = .fillEqually
        grid.alignment = .top
    }

    private func setupBindings() {}
}

private final class ToolButton: UIControl {
    var onTap: (() -> Void)?

    private let iconBackground = UIView()
    private let iconView: PrepareToolIconView
    private let titleLabel = LiveText.voiceLounge(.control, tone: .secondary, alignment: .center, emphasized: true)

    init(titleKey: String, icon: PrepareToolIcon) {
        iconView = PrepareToolIconView(icon: icon)
        super.init(frame: .zero)

        iconBackground.backgroundColor = PrepareToolStyle.iconBackground
        iconBackground.layer.cornerRadius = PrepareToolStyle.iconSize / 2
        iconBackground.layer.borderWidth = 1
        iconBackground.layer.borderColor = PrepareToolStyle.iconBorder.cgColor
        iconBackground.isUserInteractionEnabled = false
        addSubview(iconBackground)

        iconView.isUserInteractionEnabled = false
        iconBackground.addSubview(iconView)

        titleLabel.text = LiveKitResources.localizedString(titleKey)
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        iconBackground.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(PrepareToolStyle.iconSize)
        }
        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(26)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconBackground.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handleTap() { onTap?() }
}

private enum PrepareToolIcon {
    case layout
    case transcriber
    case audio

    var assetName: String? {
        switch self {
        case .layout: return "livekit_living_more"
        case .audio: return "livekit_living_setting_audio"
        case .transcriber: return nil
        }
    }
}

private final class PrepareToolIconView: UIView {
    private let icon: PrepareToolIcon
    private let imageView = UIImageView()
    private let shapeLayer = CAShapeLayer()

    init(icon: PrepareToolIcon) {
        self.icon = icon
        super.init(frame: .zero)
        backgroundColor = .clear
        if let assetName = icon.assetName {
            imageView.image = LiveKitResources.image(named: assetName)?.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = PrepareToolStyle.iconStroke
            imageView.contentMode = .scaleAspectFit
            addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalToSuperview().multipliedBy(0.62)
            }
            return
        }
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = PrepareToolStyle.iconStroke.cgColor
        shapeLayer.lineWidth = 1.8
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round
        layer.addSublayer(shapeLayer)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard icon.assetName == nil else { return }
        shapeLayer.frame = bounds
        let scale = min(bounds.width, bounds.height) / 24
        let path = UIBezierPath()
        switch icon {
        case .transcriber:
            path.append(UIBezierPath(roundedRect: CGRect(x: 3.4, y: 4.4, width: 13.2, height: 11.2), cornerRadius: 2.4))
            path.move(to: CGPoint(x: 6.6, y: 8))
            path.addLine(to: CGPoint(x: 13.6, y: 8))
            path.move(to: CGPoint(x: 6.6, y: 10.8))
            path.addLine(to: CGPoint(x: 11.2, y: 10.8))
            path.append(UIBezierPath(ovalIn: CGRect(x: 13.4, y: 12.4, width: 7.2, height: 7.2)))
            path.move(to: CGPoint(x: 17, y: 14.4))
            path.addLine(to: CGPoint(x: 17, y: 16))
            path.addLine(to: CGPoint(x: 18.2, y: 17))
        case .layout, .audio: break
        }
        path.apply(CGAffineTransform(scaleX: scale, y: scale))
        shapeLayer.path = path.cgPath
    }
}

private enum PrepareToolStyle {
    static let gridInset: CGFloat = 20
    static let gridTop: CGFloat = 64
    static let iconSize: CGFloat = 56
    static let iconBackground = VoiceLoungeColor.prepareIconBackground
    static let iconBorder = VoiceLoungeColor.prepareIconBorder
    static let iconStroke = UIColor.white.withAlphaComponent(0.92)
    static let sheetHeight: CGFloat = 64 + 56 + 8 + 18 + 28
}

private extension String {
    static var moreTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.more_title") }
}

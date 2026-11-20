import SnapKit
import UIKit

final class VoiceLoungeSeatPreviewView: UIView {
    private let gridStack = UIStackView()
    private let columnStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        gridStack.axis = .vertical
        gridStack.alignment = .center
        gridStack.spacing = SeatPreviewStyle.rowSpacing
        columnStack.axis = .vertical
        columnStack.alignment = .center
        columnStack.spacing = SeatPreviewStyle.columnSpacing
        addSubview(gridStack)
        addSubview(columnStack)
        applyLayout(.oneV8)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyLayout(_ layout: VoiceLoungeSeatLayout) {
        switch layout {
        case .oneV8, .twoV8:
            clear(columnStack)
            rebuildGrid(startIndex: layout == .twoV8 ? 2 : 1)
            activate(gridStack, inactive: columnStack)
        case .oneV8x:
            clear(gridStack)
            rebuildColumn(startIndex: 1)
            activate(columnStack, inactive: gridStack)
        case .duo:
            clear(gridStack)
            clear(columnStack)
            gridStack.isHidden = true
            columnStack.isHidden = true
            gridStack.snp.removeConstraints()
            columnStack.snp.removeConstraints()
        }
    }

    private func activate(_ active: UIStackView, inactive: UIStackView) {
        inactive.isHidden = true
        inactive.snp.removeConstraints()
        active.isHidden = false
        active.snp.remakeConstraints { make in make.edges.equalToSuperview() }
    }

    private func clear(_ stack: UIStackView) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func rebuildGrid(startIndex: Int) {
        clear(gridStack)
        var seatIndex = startIndex
        for _ in 0..<SeatPreviewStyle.rows {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .top
            row.spacing = 0
            for _ in 0..<SeatPreviewStyle.columns {
                row.addArrangedSubview(SeatPreviewCell(index: seatIndex, style: .grid))
                seatIndex += 1
            }
            gridStack.addArrangedSubview(row)
        }
    }

    private func rebuildColumn(startIndex: Int) {
        clear(columnStack)
        for offset in 0..<SeatPreviewStyle.columnCount {
            columnStack.addArrangedSubview(SeatPreviewCell(index: startIndex + offset, style: .column))
        }
    }
}

private final class SeatPreviewCell: UIView {
    enum Style { case grid, column }

    private let ringView = UIView()
    private let micView = UIImageView()
    private let label = UILabel()

    init(index: Int, style: Style) {
        super.init(frame: .zero)
        ringView.backgroundColor = SeatPreviewStyle.ringFill
        ringView.layer.cornerRadius = SeatPreviewStyle.ringSize(for: style) / 2
        ringView.layer.borderWidth = 1
        ringView.layer.borderColor = SeatPreviewStyle.ringBorder.cgColor
        addSubview(ringView)

        micView.image = LiveKitResources.image(named: "livekit_voiceprepare_seat_mic")?.withRenderingMode(
            .alwaysTemplate)
        micView.tintColor = SeatPreviewStyle.micTint
        micView.contentMode = .scaleAspectFit
        ringView.addSubview(micView)

        label.text = .seatLabel(index)
        label.font = SeatPreviewStyle.labelFont
        label.textColor = SeatPreviewStyle.labelColor
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        addSubview(label)

        snp.makeConstraints { make in make.width.equalTo(SeatPreviewStyle.cellWidth(for: style)) }
        ringView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(SeatPreviewStyle.ringSize(for: style))
        }
        micView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(SeatPreviewStyle.micSize(for: style))
        }
        label.snp.makeConstraints { make in
            make.top.equalTo(ringView.snp.bottom).offset(style == .column ? 2 : 6)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private enum SeatPreviewStyle {
    static let rows = 2
    static let columns = 4
    static let columnCount = 8
    static let rowSpacing: CGFloat = 14
    static let columnSpacing: CGFloat = 4
    static let ringFill = UIColor.white.withAlphaComponent(0.035)
    static let ringBorder = UIColor.white.withAlphaComponent(0.075)
    static let micTint = UIColor.white.withAlphaComponent(0.4)
    static let labelFont = UIFont.systemFont(ofSize: VoiceLoungeFont.size(10))
    static let labelColor = UIColor.white.withAlphaComponent(0.44)

    static func cellWidth(for style: SeatPreviewCell.Style) -> CGFloat { 75 }
    static func ringSize(for style: SeatPreviewCell.Style) -> CGFloat { 48 }
    static func micSize(for style: SeatPreviewCell.Style) -> CGFloat { 16 }
}

private extension String {
    static func seatLabel(_ index: Int) -> String {
        LiveKitResources.localizedFormat("tuilivekit.voiceroom.prepare.seat_label", index)
    }
}

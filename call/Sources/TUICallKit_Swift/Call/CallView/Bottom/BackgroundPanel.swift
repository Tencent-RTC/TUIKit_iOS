import AtomicXCore
import SnapKit
import UIKit

final class BackgroundPanel: UIView {

    private static var currentLevel = 0

    private let offOption = OptionView(icon: "callkit_icon_ban", text: CallKitResources.text("callkit.panel.off"))
    private let blurOption = OptionView(icon: "callkit_icon_person", text: CallKitResources.text("callkit.panel.blur"), gradientThumb: true)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        refreshSelection()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let titleLabel = CallPanelHeader.add(to: self, title: CallKitResources.text("callkit.panel.background_title"))

        offOption.onTap = { [weak self] in self?.apply(level: 0) }
        blurOption.onTap = { [weak self] in self?.apply(level: 2) }
        let optionsRow = UIStackView(arrangedSubviews: [offOption, blurOption])
        optionsRow.spacing = 11
        addSubview(optionsRow)
        optionsRow.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(18)
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-12)
        }
    }

    private func apply(level: Int) {
        let payload = "{\"api\":\"setBlurBackground\",\"params\":{\"level\":\(level)}}"
        CallStore.shared.callExperimentalAPI(jsonStr: payload)
        Self.currentLevel = level
        refreshSelection()
    }

    private func refreshSelection() {
        offOption.isSelected = Self.currentLevel == 0
        blurOption.isSelected = Self.currentLevel != 0
    }

    private final class OptionView: UIView {
        var onTap: (() -> Void)?
        var isSelected = false {
            didSet { applySelection() }
        }

        private let thumb = UIView()
        private let thumbGradient = CAGradientLayer()
        private let iconView = UIImageView()
        private let nameLabel = UILabel()

        init(icon: String, text: String, gradientThumb: Bool = false) {
            super.init(frame: .zero)
            thumb.backgroundColor = CallKitTheme.hairlineOnDark
            thumb.layer.cornerRadius = 10
            thumb.layer.borderWidth = 2
            thumb.clipsToBounds = true
            if gradientThumb {
                thumbGradient.colors = [UIColor(hex: 0x76816F).cgColor, UIColor(hex: 0x4C574B).cgColor]
                thumbGradient.startPoint = .zero
                thumbGradient.endPoint = CGPoint(x: 1, y: 1)
                thumb.layer.insertSublayer(thumbGradient, at: 0)
            }
            iconView.image = CallKitResources.image(named: icon)?.withRenderingMode(.alwaysTemplate)
            iconView.tintColor = .white
            iconView.contentMode = .scaleAspectFit
            thumb.addSubview(iconView)
            iconView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(26)
            }

            nameLabel.text = text
            nameLabel.font = .systemFont(ofSize: 11)
            nameLabel.textAlignment = .center

            let column = UIStackView(arrangedSubviews: [thumb, nameLabel])
            column.axis = .vertical
            column.spacing = 7
            column.alignment = .center
            column.isUserInteractionEnabled = false
            addSubview(column)
            column.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            thumb.snp.makeConstraints { make in
                make.size.equalTo(CGSize(width: 80, height: 60))
            }
            snp.makeConstraints { make in
                make.width.equalTo(80)
            }

            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            thumbGradient.frame = thumb.bounds
        }

        private func applySelection() {
            thumb.layer.borderColor = isSelected ? CallKitTheme.callGreen.cgColor : UIColor.clear.cgColor
            nameLabel.textColor = isSelected ? CallKitTheme.callGreen : CallKitTheme.sheetText4
        }

        @objc private func handleTap() {
            onTap?()
        }
    }
}

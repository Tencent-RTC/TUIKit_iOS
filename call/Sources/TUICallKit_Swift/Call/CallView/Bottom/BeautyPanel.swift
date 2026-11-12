import AtomicXCore
import Combine
import SnapKit
import UIKit

final class BeautyPanel: UIView {

    private final class SliderRow: UIView {
        var onChange: ((Float) -> Void)?

        private let slider = UISlider()
        private let valueLabel = UILabel()

        init(name: String, value: Float) {
            super.init(frame: .zero)
            let iconView = UIImageView(image: CallKitResources.image(named: "callkit_icon_beauty")?.withRenderingMode(.alwaysTemplate))
            iconView.tintColor = .white
            iconView.contentMode = .scaleAspectFit
            iconView.snp.makeConstraints { make in
                make.size.equalTo(22)
            }

            let nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = .systemFont(ofSize: 13)
            nameLabel.textColor = CallKitTheme.sheetText4
            nameLabel.snp.makeConstraints { make in
                make.width.equalTo(34)
            }

            slider.maximumValue = 9
            slider.minimumTrackTintColor = UIColor.white.withAlphaComponent(0.18)
            slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.18)
            slider.setThumbImage(Self.thumbImage, for: .normal)

            valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            valueLabel.textColor = .white
            valueLabel.textAlignment = .right
            valueLabel.snp.makeConstraints { make in
                make.width.equalTo(28)
            }

            let row = UIStackView(arrangedSubviews: [iconView, nameLabel, slider, valueLabel])
            row.spacing = 12
            row.alignment = .center
            addSubview(row)
            row.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            slider.addTarget(self, action: #selector(handleChange), for: .valueChanged)
            setValue(value)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setValue(_ value: Float) {
            let rounded = value.rounded()
            slider.value = rounded
            valueLabel.text = String(Int(rounded))
        }

        @objc private func handleChange() {
            setValue(slider.value)
            onChange?(slider.value)
        }

        private static let thumbImage: UIImage? = {
            let canvasSize = CGSize(width: 22, height: 22)
            let renderer = UIGraphicsImageRenderer(size: canvasSize)
            return renderer.image { context in
                let rect = CGRect(x: 4, y: 4, width: 14, height: 14)
                context.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.35).cgColor)
                UIColor.white.setFill()
                UIBezierPath(ovalIn: rect).fill()
            }
        }()
    }

    private var cancellables = Set<AnyCancellable>()
    private var whitenessRow: SliderRow!
    private var smoothRow: SliderRow!
    private var ruddyRow: SliderRow!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews(state: BaseBeautyStore.shared.state.value)
        subscribeState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews(state: BaseBeautyState) {
        let titleLabel = CallPanelHeader.add(to: self, title: CallKitResources.text("callkit.panel.beauty_title"))

        whitenessRow = SliderRow(name: CallKitResources.text("callkit.beauty.whiteness"), value: state.whitenessLevel)
        smoothRow = SliderRow(name: CallKitResources.text("callkit.beauty.smooth"), value: state.smoothLevel)
        ruddyRow = SliderRow(name: CallKitResources.text("callkit.beauty.ruddy"), value: state.ruddyLevel)

        whitenessRow.onChange = { BaseBeautyStore.shared.setWhitenessLevel(whitenessLevel: $0) }
        smoothRow.onChange = { BaseBeautyStore.shared.setSmoothLevel(smoothLevel: $0) }
        ruddyRow.onChange = { BaseBeautyStore.shared.setRuddyLevel(ruddyLevel: $0) }

        let column = UIStackView(arrangedSubviews: [whitenessRow, smoothRow, ruddyRow])
        column.axis = .vertical
        column.spacing = 18
        addSubview(column)
        column.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-12)
        }
    }

    private func subscribeState() {
        BaseBeautyStore.shared.state
            .subscribe(StatePublisherSelector { "\($0.whitenessLevel)|\($0.smoothLevel)|\($0.ruddyLevel)" })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                let state = BaseBeautyStore.shared.state.value
                self?.whitenessRow.setValue(state.whitenessLevel)
                self?.smoothRow.setValue(state.smoothLevel)
                self?.ruddyRow.setValue(state.ruddyLevel)
            }
            .store(in: &cancellables)
    }
}

import SnapKit
import UIKit

final class MoreMenuBubble: CallKitBubble {

    enum Item {
        case blurBackground
        case beauty
    }

    var onSelect: ((Item) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        if CallKitConfig.shared.enableVirtualBackground {
            stackView.addArrangedSubview(makeRow(icon: "callkit_icon_blur", text: CallKitResources.text("callkit.more.blur_background"), item: .blurBackground))
            let separatorContainer = UIView()
            let separator = UIView()
            separator.backgroundColor = CallKitTheme.hairlineOnDark
            separatorContainer.addSubview(separator)
            separator.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(18)
                make.top.bottom.equalToSuperview()
                make.height.equalTo(1)
            }
            stackView.addArrangedSubview(separatorContainer)
        }
        stackView.addArrangedSubview(makeRow(icon: "callkit_icon_beauty", text: CallKitResources.text("callkit.more.beauty"), item: .beauty))
    }

    private func makeRow(icon: String, text: String, item: Item) -> UIView {
        let row = UIControl()
        let iconView = UIImageView(image: CallKitResources.image(named: icon)?.withRenderingMode(.alwaysTemplate))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.snp.makeConstraints { make in
            make.size.equalTo(22)
        }

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15)
        label.textColor = .white

        let rowStack = UIStackView(arrangedSubviews: [iconView, label])
        rowStack.spacing = 12
        rowStack.alignment = .center
        rowStack.isUserInteractionEnabled = false
        row.addSubview(rowStack)
        rowStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 18, bottom: 12, right: 18))
        }
        row.addAction(UIAction { [weak self] _ in self?.onSelect?(item) }, for: .touchUpInside)
        return row
    }
}

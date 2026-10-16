import SnapKit
import UIKit

final class GiftCategoryTabsView: UIView {
    var onSelect: ((Int) -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var buttons: [UIButton] = []
    private var underlineViews: [UIView] = []
    private var underlineGradients: [CAGradientLayer] = []
    private var selectedIndex: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.spacing = 24
        stackView.layoutMargins = UIEdgeInsets(top: 0, left: 17, bottom: 0, right: 17)
        stackView.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(scrollView)
        }
    }

    func setCategories(_ names: [String]) {
        buttons.forEach { $0.removeFromSuperview() }
        underlineViews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        underlineViews.removeAll()
        underlineGradients.removeAll()
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, name) in names.enumerated() {
            let container = UIView()

            let button = UIButton(type: .custom)
            button.setTitle(name, for: .normal)
            button.titleLabel?.font = GiftCategoryTabsViewTypography.buttonFont
            button.tag = index
            button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 1)
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            container.addSubview(button)

            let underline = UIView()
            underline.isHidden = true
            let gradient = CAGradientLayer()
            gradient.colors = [
                GiftPanelStyle.blue.cgColor,
                GiftPanelStyle.deepBlue.cgColor,
            ]
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            gradient.cornerRadius = 1
            underline.layer.addSublayer(gradient)
            container.addSubview(underline)

            button.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }

            underline.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(6)
                make.trailing.equalToSuperview().offset(-6)
                make.bottom.equalToSuperview()
                make.height.equalTo(2)
            }

            stackView.addArrangedSubview(container)
            buttons.append(button)
            underlineViews.append(underline)
            underlineGradients.append(gradient)
        }

        if selectedIndex >= names.count { selectedIndex = 0 }
        applySelection()
        setNeedsLayout()
        layoutIfNeeded()
    }

    func setSelectedIndex(_ index: Int, animated: Bool) {
        guard buttons.indices.contains(index) else { return }
        if index == selectedIndex {
            applySelection()
            return
        }
        selectedIndex = index
        applySelection()
        scrollButtonToVisible(at: index, animated: animated)
    }

    @objc private func tabTapped(_ sender: UIButton) {
        let index = sender.tag
        guard buttons.indices.contains(index) else { return }
        if index != selectedIndex {
            selectedIndex = index
            applySelection()
            scrollButtonToVisible(at: index, animated: true)
        }
        onSelect?(index)
    }

    private func applySelection() {
        for (index, button) in buttons.enumerated() {
            let selected = index == selectedIndex
            button.setTitleColor(
                selected ? UIColor.white : UIColor.white.withAlphaComponent(0.5),
                for: .normal
            )
            button.titleLabel?.font = .systemFont(
                ofSize: 14,
                weight: selected ? .bold : .regular
            )
            underlineViews[index].isHidden = !selected
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (index, underline) in underlineViews.enumerated() {
            guard underlineGradients.indices.contains(index) else { continue }
            underlineGradients[index].frame = underline.bounds
        }
    }

    private func scrollButtonToVisible(at index: Int, animated: Bool) {
        guard buttons.indices.contains(index) else { return }
        let button = buttons[index]
        let frame = button.superview?.convert(button.frame, to: scrollView) ?? .zero
        let visibleRect = CGRect(
            x: scrollView.contentOffset.x,
            y: 0,
            width: scrollView.bounds.width,
            height: scrollView.bounds.height
        )
        if !visibleRect.contains(frame) {
            scrollView.scrollRectToVisible(frame.insetBy(dx: -16, dy: 0), animated: animated)
        }
    }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum GiftCategoryTabsViewTypography {
    static let buttonFont: UIFont = UIFont.systemFont(ofSize: 14, weight: .regular)
}

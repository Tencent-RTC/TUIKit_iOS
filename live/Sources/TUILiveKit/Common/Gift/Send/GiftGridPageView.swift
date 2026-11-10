import Kingfisher
import SnapKit
import UIKit

final class GiftGridPageView: UIView {
    typealias GiftItem = GiftSendPanelView.GiftItem

    enum SelectionState {
        case none
        case selected(String)
        case combo(String)
    }

    var onCellTapped: ((GiftItem) -> Void)?
    var onComboSend: ((GiftItem) -> Void)?
    var onComboExpired: (() -> Void)?

    private(set) var gifts: [GiftItem] = []
    private(set) var selection: SelectionState = .none

    private let scrollView = UIScrollView()
    private var cells: [GiftItemView] = []
    private var comboButtons: [GiftSendComboButton] = []
    private let columns: Int = 4
    private let cellSpacing: CGFloat = 4
    private let rowSpacing: CGFloat = 2
    private let horizontalPadding: CGFloat = 10
    private let rowHeight: CGFloat = 104

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in make.edges.equalToSuperview() }
    }

    func update(gifts: [GiftItem]) {
        self.gifts = gifts
        ensureCells(count: gifts.count)
        applyAll()
    }

    func setSelection(_ selection: SelectionState) {
        self.selection = selection
        applyAll()
    }

    func clearSelection() { setSelection(.none) }

    private func ensureCells(count: Int) {
        while cells.count < count {
            let index = cells.count
            let cell = GiftItemView()
            cell.onTap = { [weak self, weak cell] in
                guard let self, let cell, let giftID = cell.giftID,
                    let gift = self.gifts.first(where: { $0.id == giftID })
                else { return }
                self.onCellTapped?(gift)
            }
            let combo = GiftSendComboButton()
            combo.isHidden = true
            combo.onSendOnce = { [weak self, weak combo] in
                guard let self, let combo, let giftID = combo.giftID,
                    let gift = self.gifts.first(where: { $0.id == giftID })
                else { return }
                self.onComboSend?(gift)
            }
            combo.onExpired = { [weak self] in self?.onComboExpired?() }
            scrollView.addSubview(cell)
            scrollView.addSubview(combo)
            cells.append(cell)
            comboButtons.append(combo)
            _ = index
        }
    }

    private func applyAll() {
        for (index, cell) in cells.enumerated() {
            if index >= gifts.count {
                cell.isHidden = true
                comboButtons[index].isHidden = true
                comboButtons[index].end()
                continue
            }
            let gift = gifts[index]
            let combo = comboButtons[index]

            switch selection {
            case .none:
                cell.isHidden = false
                combo.isHidden = true
                if combo.giftID != nil { combo.end() }
                cell.configure(gift: gift, state: .normal)
            case .selected(let selectedID):
                if gift.id == selectedID {
                    cell.isHidden = false
                    combo.isHidden = true
                    if combo.giftID != nil { combo.end() }
                    cell.configure(gift: gift, state: .selected)
                } else {
                    cell.isHidden = false
                    combo.isHidden = true
                    if combo.giftID != nil { combo.end() }
                    cell.configure(gift: gift, state: .normal)
                }
            case .combo(let comboID):
                if gift.id == comboID {
                    cell.isHidden = true
                    combo.isHidden = false
                    if combo.giftID != gift.id { combo.begin(with: gift) }
                } else {
                    cell.isHidden = false
                    combo.isHidden = true
                    if combo.giftID != nil { combo.end() }
                    cell.configure(gift: gift, state: .normal)
                }
            }
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let totalSpacing = cellSpacing * CGFloat(columns - 1)
        let availableWidth = bounds.width - horizontalPadding * 2 - totalSpacing
        let cellWidth = floor(availableWidth / CGFloat(columns))
        let cellHeight = rowHeight

        var visibleIndex = 0
        var maxBottom: CGFloat = 0
        for (index, cell) in cells.enumerated() {
            guard index < gifts.count else {
                cell.frame = .zero
                comboButtons[index].frame = .zero
                continue
            }
            let row = visibleIndex / columns
            let column = visibleIndex % columns
            let x = horizontalPadding + CGFloat(column) * (cellWidth + cellSpacing)
            let y = CGFloat(row) * (cellHeight + rowSpacing) + 6
            let frame = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
            cell.frame = frame
            comboButtons[index].frame = frame
            maxBottom = max(maxBottom, y + cellHeight)
            visibleIndex += 1
        }
        let totalHeight = maxBottom + 14
        scrollView.contentSize = CGSize(width: bounds.width, height: totalHeight)
    }
}

// MARK: - Gift item

private final class GiftItemView: UIControl {
    enum State {
        case normal
        case selected
        case combo
    }

    struct Style {
        static let iconSize: CGFloat = 44
        static let selectedBorderColor = GiftPanelStyle.blue.withAlphaComponent(0.7)
        static let selectedBackgroundColor = GiftPanelStyle.blue.withAlphaComponent(0.15)
        static let coinColor = GiftPanelStyle.coin
        static let sendGradientStart = GiftPanelStyle.blue
        static let sendGradientEnd = GiftPanelStyle.deepBlue
    }

    var onTap: (() -> Void)?

    private(set) var giftID: String?

    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let priceStack = UIStackView()
    private let coinDot = UIView()
    private let priceLabel = UILabel()
    private let sendButton = UIButton(type: .custom)
    private let sendGradientLayer = CAGradientLayer()
    private let borderLayer = CAShapeLayer()

    private var currentState: State = .normal
    private var currentIconURL: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        backgroundColor = .clear
        layer.cornerRadius = 10
        layer.masksToBounds = false

        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 1
        layer.addSublayer(borderLayer)

        iconView.contentMode = .scaleAspectFit
        iconView.clipsToBounds = true
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        nameLabel.font = GiftItemTypography.nameFont
        nameLabel.textColor = GiftItemStyle.foreground
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.isUserInteractionEnabled = false
        addSubview(nameLabel)

        coinDot.backgroundColor = Style.coinColor
        coinDot.layer.cornerRadius = 4
        coinDot.isUserInteractionEnabled = false

        priceLabel.textColor = GiftItemStyle.foreground
        priceLabel.font = GiftItemTypography.priceFont
        priceLabel.isUserInteractionEnabled = false

        priceStack.axis = .horizontal
        priceStack.alignment = .center
        priceStack.spacing = 4
        priceStack.isUserInteractionEnabled = false
        priceStack.addArrangedSubview(coinDot)
        priceStack.addArrangedSubview(priceLabel)
        addSubview(priceStack)

        sendGradientLayer.colors = [Style.sendGradientStart.cgColor, Style.sendGradientEnd.cgColor]
        sendGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        sendGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)

        sendButton.setTitle(LiveKitResources.localizedString("tuilivekit.player.gift.send"), for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = GiftItemTypography.sendButtonFont
        sendButton.layer.cornerRadius = 11
        sendButton.layer.masksToBounds = true
        sendButton.layer.insertSublayer(sendGradientLayer, at: 0)
        sendButton.isHidden = true
        sendButton.isUserInteractionEnabled = false
        addSubview(sendButton)

        iconView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10)
            make.width.height.equalTo(Style.iconSize)
        }

        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(2)
            make.trailing.equalToSuperview().offset(-2)
        }

        coinDot.snp.makeConstraints { make in make.width.height.equalTo(8) }

        sendButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(6)
            make.trailing.equalToSuperview().offset(-6)
            make.bottom.equalToSuperview().offset(-6)
            make.height.equalTo(22)
        }

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    func configure(gift: GiftSendPanelView.GiftItem, state: State) {
        giftID = gift.id
        nameLabel.text = gift.name
        priceLabel.text = "\(gift.coins)"
        applyState(state)

        let urlString = gift.iconURL?.absoluteString ?? ""
        if currentIconURL != urlString {
            currentIconURL = urlString
            iconView.kf.cancelDownloadTask()
            iconView.image = nil
            iconView.kf.setImage(with: URL(string: urlString), placeholder: iconView.image)
        }
    }

    func applyState(_ state: State) {
        currentState = state
        switch state {
        case .normal:
            isHidden = false
            backgroundColor = .clear
            borderLayer.strokeColor = UIColor.clear.cgColor
            nameLabel.isHidden = false
            priceStack.isHidden = false
            priceLabel.font = GiftItemTypography.priceFont
            sendButton.isHidden = true
        case .selected:
            isHidden = false
            backgroundColor = Style.selectedBackgroundColor
            borderLayer.strokeColor = Style.selectedBorderColor.cgColor
            nameLabel.isHidden = true
            priceStack.isHidden = false
            priceLabel.font = GiftItemTypography.selectedPriceFont
            sendButton.isHidden = false
        case .combo: isHidden = true
        }
        priceStack.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            if case .selected = state {
                make.bottom.equalTo(sendButton.snp.top).offset(-4)
            } else {
                make.top.equalTo(nameLabel.snp.bottom).offset(2)
            }
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        borderLayer.frame = bounds
        borderLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: 10).cgPath
        sendGradientLayer.frame = sendButton.bounds
        sendGradientLayer.cornerRadius = sendButton.bounds.height / 2
    }

    @objc private func handleTap() { onTap?() }
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum GiftItemStyle { static let foreground: UIColor = UIColor.white.withAlphaComponent(0.94) }

private enum GiftItemTypography {
    static let nameFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    static let priceFont: UIFont = UIFont.systemFont(ofSize: 10, weight: .regular)
    static let sendButtonFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    static let selectedPriceFont: UIFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
}

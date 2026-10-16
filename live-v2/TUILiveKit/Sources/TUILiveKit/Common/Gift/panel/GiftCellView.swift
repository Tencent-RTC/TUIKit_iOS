import Kingfisher
import SnapKit
import UIKit

final class GiftCellView: UIControl {
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

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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

        nameLabel.font = GiftCellViewTypography.nameFont
        nameLabel.textColor = GiftCellStyle.foreground
        nameLabel.textAlignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.isUserInteractionEnabled = false
        addSubview(nameLabel)

        coinDot.backgroundColor = Style.coinColor
        coinDot.layer.cornerRadius = 4
        coinDot.isUserInteractionEnabled = false

        priceLabel.textColor = GiftCellStyle.foreground
        priceLabel.font = GiftCellViewTypography.priceFont
        priceLabel.isUserInteractionEnabled = false

        priceStack.axis = .horizontal
        priceStack.alignment = .center
        priceStack.spacing = 4
        priceStack.isUserInteractionEnabled = false
        priceStack.addArrangedSubview(coinDot)
        priceStack.addArrangedSubview(priceLabel)
        addSubview(priceStack)

        sendGradientLayer.colors = [
            Style.sendGradientStart.cgColor,
            Style.sendGradientEnd.cgColor,
        ]
        sendGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        sendGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)

        sendButton.setTitle(LiveKitResources.localizedString("tuilivekit.player.gift.send"), for: .normal)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.titleLabel?.font = GiftCellViewTypography.sendButtonFont
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

        priceStack.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
            make.centerX.equalToSuperview()
        }

        coinDot.snp.makeConstraints { make in
            make.width.height.equalTo(8)
        }

        sendButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(6)
            make.trailing.equalToSuperview().offset(-6)
            make.bottom.equalToSuperview().offset(-6)
            make.height.equalTo(22)
        }

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    func configure(gift: GiftUIStore.GiftItem, state: State) {
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
            priceLabel.font = GiftCellViewTypography.priceFont
            sendButton.isHidden = true
        case .selected:
            isHidden = false
            backgroundColor = Style.selectedBackgroundColor
            borderLayer.strokeColor = Style.selectedBorderColor.cgColor
            nameLabel.isHidden = true
            priceStack.isHidden = false
            priceLabel.font = GiftCellViewTypography.selectedPriceFont
            sendButton.isHidden = false
        case .combo:
            isHidden = true
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

    @objc private func handleTap() {
        onTap?()
    }
}

enum GiftPanelStyle {
    static let blue: UIColor = UIColor(red: 74/255.0, green: 158/255.0, blue: 255/255.0, alpha: 1)
    static let deepBlue: UIColor = UIColor(red: 0/255.0, green: 82/255.0, blue: 217/255.0, alpha: 1)
    static let coin: UIColor = UIColor(red: 1.0, green: 0.792, blue: 0.298, alpha: 1)
}

// Styles owned by this component or feature. Values preserve the existing design.
private enum GiftCellStyle {
    static let foreground: UIColor = UIColor.white.withAlphaComponent(0.94)
}

private enum GiftCellViewTypography {
    static let nameFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    static let priceFont: UIFont = UIFont.systemFont(ofSize: 10, weight: .regular)
    static let sendButtonFont: UIFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    static let selectedPriceFont: UIFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
}

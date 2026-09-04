import UIKit
import SnapKit

final class MessageCenteredTextCell: UITableViewCell {
    private static let timeTopPadding = CGFloat(SpacingScheme.contentSpacing)

    private static let timeBottomPadding = CGFloat(SpacingScheme.contentSpacing)

    private static let tipBottomPadding = CGFloat(SpacingScheme.contentSpacing)

    private static let tipHorizontalMargin = CGFloat(SpacingScheme.normalSpacing)

    private let timeLabel = UILabel()

    private let tipLabel = UILabel()

    private var timeHeightConstraint: Constraint?

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configure

    func configure(text: String, timeString: String?, showTime: Bool) {
        if let timeString = timeString, showTime, !timeString.isEmpty {
            timeLabel.text = timeString
            timeLabel.isHidden = false
            timeLabel.snp.updateConstraints { $0.top.equalToSuperview().offset(Self.timeTopPadding) }
            timeHeightConstraint?.deactivate()
        } else {
            timeLabel.text = nil
            timeLabel.isHidden = true
            timeLabel.snp.updateConstraints { $0.top.equalToSuperview().offset(0) }
            timeHeightConstraint?.activate()
        }
        tipLabel.text = text
        tipLabel.isHidden = text.isEmpty
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        timeLabel.text = nil
        tipLabel.text = nil
    }

    private func constructViewHierarchy() {
        selectionStyle = .none
        contentView.addSubview(timeLabel)
        contentView.addSubview(tipLabel)
    }

    private func activateConstraints() {
        timeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Self.timeTopPadding)
            make.centerX.equalToSuperview()
            timeHeightConstraint = make.height.equalTo(0).constraint
        }
        tipLabel.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(Self.timeBottomPadding)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(Self.tipHorizontalMargin)
            make.trailing.lessThanOrEqualToSuperview().offset(-Self.tipHorizontalMargin)
            make.bottom.equalToSuperview().offset(-Self.tipBottomPadding)
        }
    }

    private func setupViewStyle() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        timeLabel.textAlignment = .center
        timeLabel.font = FontScheme.caption2Regular
        timeLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
        tipLabel.textAlignment = .center
        tipLabel.numberOfLines = 0
        tipLabel.font = FontScheme.caption2Regular
        tipLabel.textColor = TUIChatKitTheme.colors.textColorSecondary
    }
}

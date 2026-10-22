import UIKit
import SnapKit

final class RoomParticipantSectionCell: UITableViewCell {

    static let reuseIdentifier = "RoomParticipantSectionCell"

    var onToggle: (() -> Void)?

    private let titleText = UILabel()
    private let countText = UILabel()
    private let chevron = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
        setupStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    private func setupViews() {
        contentView.addSubview(titleText)
        contentView.addSubview(countText)
        contentView.addSubview(chevron)
    }

    private func setupConstraints() {
        chevron.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(24)
            $0.centerY.equalTo(titleText)
            $0.size.equalTo(12)
        }
        titleText.snp.makeConstraints {
            $0.leading.equalTo(chevron.snp.trailing).offset(6)
            $0.top.equalToSuperview()
            $0.bottom.equalToSuperview().offset(-4)
        }
        countText.snp.makeConstraints {
            $0.leading.equalTo(titleText.snp.trailing).offset(6)
            $0.centerY.equalTo(titleText)
        }
    }

    private func setupStyles() {
        selectionStyle = .none
        backgroundColor = .clear
        titleText.font = .boldSystemFont(ofSize: 11)
        titleText.textColor = UIColor.roomKitFgSecondary
        countText.font = .boldSystemFont(ofSize: 11)
        countText.textColor = UIColor.roomKitFgTertiary
        chevron.contentMode = .scaleAspectFit
        chevron.image = RoomKitResources.image(named: "roomkit_icon_chevron_right_tertiary")
    }


    func bind(title: String, count: Int, collapsed: Bool) {
        titleText.text = title
        countText.text = "(\(count))"
        UIView.performWithoutAnimation {
            chevron.transform = collapsed ? .identity : CGAffineTransform(rotationAngle: .pi / 2)
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            onToggle?()
        }
    }
}

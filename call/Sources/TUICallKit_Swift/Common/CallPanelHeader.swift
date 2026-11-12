import SnapKit
import UIKit

enum CallPanelHeader {

    @discardableResult
    static func add(to container: UIView, title: String) -> UILabel {
        let grabber = UIView()
        grabber.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        grabber.layer.cornerRadius = 2
        container.addSubview(grabber)
        grabber.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.size.equalTo(CGSize(width: 36, height: 4))
        }

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17)
        titleLabel.textColor = .white
        container.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(grabber.snp.bottom).offset(18)
            make.leading.equalToSuperview().offset(20)
        }
        return titleLabel
    }
}

//
//  LocalCoHostEmptyView.swift
//  Pods
//
//  Created by ssc on 2025/11/17.
//
import RTCRoomEngine
import SnapKit
import Combine
import AtomicXCore
import AtomicX

class LocalCoHostEmptyView: UIView {
    var didTap: (() -> Void)?
    private let userInfo: SeatInfo
    private let imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.image = internalImage("add")
        return imageView
    }()

    private let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.font = .customFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = .white.withAlphaComponent(0.55)
        titleLabel.text = .emptySeatText
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        return titleLabel
    }()

    init(seatInfo: SeatInfo) {
        userInfo = seatInfo
        super.init(frame: .zero)

        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor

        addSubview(titleLabel)
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(27.scale375())
            make.centerX.equalToSuperview()
            make.height.width.equalTo(18.scale375())
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview()
        }

        imageView.image = seatInfo.isLocked == true ? internalImage("seat_locked_icon") : internalImage("add")
        titleLabel.text = seatInfo.isLocked == true ? .locKSeat : .emptySeatText

        self.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        self.gradient(colors: [
            UIColor.b1.withAlphaComponent(0.2),
            UIColor.b1.withAlphaComponent(0.1)
        ], isVertical: true)
    }

    @objc private func handleTap() {
        didTap?()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate extension String {
    static let emptySeatText: String = internalLocalized("common_wait_connection")
    static let inviteText = internalLocalized("common_voiceroom_invite")
    static let locKSeat = internalLocalized("seat_locked")
    static let noOneOnSeatText = internalLocalized("seat_no_guest")
}

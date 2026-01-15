//
//  GiftListPanel.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/11/7.
//

import Foundation
import SnapKit
import Combine
import RTCRoomEngine

class GiftListPanel: UIView {
    private let roomId: String
    private var cancellableSet: Set<AnyCancellable> = []
    private lazy var giftListView = GiftListView(roomId: roomId)

    init(roomId: String) {
        self.roomId = roomId
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        backgroundColor = .clear
        constructViewHierarchy()
        activateConstraints()
        isViewReady = true
    }

    
    deinit {
        debugPrint("\(type(of: self)) deinit")
    }
}

// MARK: Layout

extension GiftListPanel {
    private func constructViewHierarchy() {
        backgroundColor = .bgOperateColor
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(giftListView)
    }

    private func activateConstraints() {
        giftListView.snp.remakeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(256)
            make.top.equalToSuperview().offset(20.scale375Height())
            make.bottom.equalToSuperview()
        }
    }
}

private extension String {
    static let giftTitle = internalLocalized("common_gift_title")
    static let giftMutedText = internalLocalized("common_muted_gift")
}

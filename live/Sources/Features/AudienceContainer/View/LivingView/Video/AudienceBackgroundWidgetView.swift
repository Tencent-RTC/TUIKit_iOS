//
//  AudienceBackgroundWidgetView.swift
//  TUILiveKit
//
//  Created by gg on 2025/7/17.
//

import SnapKit
import RTCCommon
import Combine
import AtomicX

class AudienceBackgroundWidgetView: UIView {
    init(avatarUrl: String) {
        super.init(frame: .zero)
        
        backgroundColor = .bgOperateColor
        
        addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        avatarView.setContent(.url(avatarUrl, placeholder: UIImage.avatarPlaceholderImage))
        
        subscribeState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var cancellableSet = Set<AnyCancellable>()
    
    private lazy var avatarView: AtomicAvatar = {
        let avatar = AtomicAvatar(
            content: .url("",placeholder: UIImage.avatarPlaceholderImage),
            size: .m,
            shape: .round
        )
        return avatar
    }()
    
    func subscribeState() {
        FloatWindow.shared.subscribeShowingState()
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isShow in
                guard let self = self else { return }
                isHidden = isShow
            }
            .store(in: &cancellableSet)
    }
}

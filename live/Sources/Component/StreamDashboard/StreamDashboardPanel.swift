//
//  StreamDashboardPanel.swift
//  TUILiveKit
//
//  Created by jack on 2024/11/21.
//

import Foundation
import AtomicX

class StreamDashboardPanel: UIView {
    
    private let liveID: String
    
    private lazy var titleLabel: AtomicLabel = {
        let label = AtomicLabel(.dashboardText) { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Medium16)
        }
        label.textAlignment = .center
        return label
    }()
    
    private lazy var networkInfoView = StreamDashboardNetView()
    private lazy var mediaView = StreamDashboardMediaView(liveID: liveID)
    
    init(liveID: String) {
        self.liveID = liveID
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
    }
    
}

extension StreamDashboardPanel {
    
    private func constructViewHierarchy() {
        addSubview(titleLabel)
        addSubview(networkInfoView)
        addSubview(mediaView)
    }
    
    private func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20.scale375Height())
            make.centerX.equalToSuperview()
        }
        networkInfoView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(12.scale375Height())
            make.height.equalTo(48.scale375Height())
        }
        mediaView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(networkInfoView.snp.bottom).offset(8.scale375Height())
            make.bottom.equalToSuperview()
        }
    }
    
    private func setupViewStyle() {
        backgroundColor = .bgOperateColor
        layer.cornerRadius = 16
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }
}


fileprivate extension String {
    static let dashboardText = internalLocalized("common_dashboard_title")
}

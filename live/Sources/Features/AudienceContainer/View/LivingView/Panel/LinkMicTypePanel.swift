//
//  LinkMicTypePanel.swift
//  TUILiveKit
//
//  Created by krabyu on 2023/10/25.
//

import Foundation
import RTCCommon
import AtomicX

class LinkMicTypePanel: UIView {
    
    private var isPortrait: Bool = {
        WindowUtils.isPortrait
    }()

    let data: [LinkMicTypeCellData]
    let routerManager: AudienceRouterManager
    let manager: AudienceStore
    let seatIndex: Int
    
    init(data: [LinkMicTypeCellData], routerManager: AudienceRouterManager, manager: AudienceStore, seatIndex: Int) {
        self.data = data
        self.routerManager = routerManager
        self.manager = manager
        self.seatIndex = seatIndex
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        backgroundColor = .g2
        isViewReady = true
    }

    private let titleLabel: AtomicLabel = {
        let view = AtomicLabel(.linkTypeTitleText) { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Regular16)
        }
        view.textAlignment = .center
        return view
    }()

    private let tipsLabel: AtomicLabel = {
        let view = AtomicLabel(.linkTypeTipsText) { theme in
            LabelAppearance(textColor: theme.color.textColorSecondary,
                            font: theme.typography.Regular12)
        }
        
        view.textAlignment = .center
        view.numberOfLines = 0
        view.lineBreakMode = .byWordWrapping
        return view
    }()
    
    private lazy var videoSettingButton: UIButton = {
        let view = UIButton()
        view.setImage(internalImage("live_link_video_setting"), for: .normal)
        view.addTarget(self, action: #selector(videoSettingImageViewAction), for: .touchUpInside)
        return view
        
    }()

    private lazy var linkMicTypeTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(LinkMicTypeCell.self, forCellReuseIdentifier: LinkMicTypeCell.cellReuseIdentifier)
        return tableView
    }()
}

// MARK: Layout
extension LinkMicTypePanel {
    func constructViewHierarchy() {
        backgroundColor = .b2d
        layer.cornerRadius = 20
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(titleLabel)
        addSubview(tipsLabel)
        addSubview(videoSettingButton)
        addSubview(linkMicTypeTableView)
    }

    func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20.scale375Height())
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(24.scale375Height())
        }

        tipsLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8.scale375Height())
            make.centerX.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalTo(17.scale375Height())
        }
        
        videoSettingButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(38.scale375Height())
            make.width.height.equalTo(20.scale375())
            make.trailing.equalToSuperview().offset(-16.scale375())
        }

        linkMicTypeTableView.snp.makeConstraints { make in
            if isPortrait {
                make.height.equalTo(234.scale375Height())
            } else {
                make.width.equalTo(375)
            }
            make.top.equalTo(tipsLabel.snp.bottom).offset(20.scale375Height())
            make.width.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
}

extension LinkMicTypePanel {
    @objc func videoSettingImageViewAction() {
        routerManager.router(action: .present(.linkSetting(seatIndex: seatIndex)))
    }
}

extension LinkMicTypePanel: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55.scale375Height()
    }
}

extension LinkMicTypePanel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LinkMicTypeCell.cellReuseIdentifier, for: indexPath)
        if let cell = cell as? LinkMicTypeCell {
            cell.data = data[indexPath.row]
        }
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let data = data[indexPath.row]
        data.action?()
    }
}

private extension String {
    static var linkTypeTitleText: String {
        internalLocalized("common_title_link_mic_selector")
    }

    static var linkTypeTipsText: String {
        internalLocalized("common_text_link_mic_selector")
    }

    static var videoLinkRequestText: String {
        internalLocalized("common_text_link_mic_video")
    }

    static var audioLinkRequestText: String {
        internalLocalized("common_text_link_mic_audio")
    }
}

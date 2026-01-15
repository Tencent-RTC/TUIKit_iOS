//
//  NetWorkInfoItemView.swift
//  Pods
//
//  Created by ssc on 2025/5/13.
//
import UIKit
import SnapKit
import RTCCommon
import Combine
import AtomicX

class NetWorkInfoItemCell: UITableViewCell {
    static let reuseIdentifier = "NetWorkInfoItemCell"

    private let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let titleLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Medium14)
        }
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "pingFangSC-Medium", size: 14)
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        return label
    }()

    private let detailScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.isScrollEnabled = true
        return scrollView
    }()

    private let detailLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorSecondary,
                            font: theme.typography.Regular12)
        }
        return label
    }()

    private let rightComponentsView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        return view
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#48494F")
        return view
    }()

    private let rightLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorSecondary,
                            font: theme.typography.Regular12)
        }
        return label
    }()

    private let arrowIcon: UIImageView = {
        let view = UIImageView()
        view.image = internalImage("live_networkinfo_arrow", rtlFlipped: true)
        view.tintColor = UIColor.white.withAlphaComponent(0.55)
        return view
    }()
    
    private lazy var slider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        slider.value = 100
        slider.minimumTrackTintColor = .blueColor
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.2)
        slider.setThumbImage(internalImage("live_networinfo_slider"), for: .normal)
        slider.isHidden = true
        return slider
    }()
    
    private lazy var volumeLabel: AtomicLabel = {
        let label = AtomicLabel("100") { theme in
            LabelAppearance(textColor: theme.color.textColorSecondary,
                            font: theme.typography.Regular12)
        }
        label.isHidden = true
        return label
    }()

    private var type: NetWorkInfoItemViewType?
    var onRightComponentsTapped: (() -> Void)?
    var onSliderValueChanged: ((Float) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
    }

    private var isViewReady: Bool = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        isViewReady = true
    }


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func constructViewHierarchy() {
        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(detailScrollView)
        detailScrollView.addSubview(detailLabel)
        contentView.addSubview(rightComponentsView)
        rightComponentsView.addSubview(separatorView)
        rightComponentsView.addSubview(rightLabel)
    }

    private func  bindInteraction() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleRightComponentsTap))
        tap.cancelsTouchesInView = false
        rightComponentsView.addGestureRecognizer(tap)
        slider.addTarget(self, action: #selector(handleSliderValueChanged), for: .valueChanged)
    }

    private func activateConstraints() {
        contentView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(66.scale375())
        }

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview().offset(1.scale375())
            make.width.height.equalTo(20.scale375())
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(6.scale375())
            make.top.equalTo(iconView)
            make.height.equalTo(22.scale375())
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing)
            make.top.equalTo(iconView)
            make.height.equalTo(22.scale375())
        }

        detailScrollView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(6.scale375())
            make.top.equalTo(titleLabel.snp.bottom).offset(4.scale375())
            make.height.equalTo(20.scale375())
            make.width.equalTo(200.scale375())
        }

        detailLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
            make.width.greaterThanOrEqualToSuperview()
        }

        rightComponentsView.snp.makeConstraints { make in
            make.leading.equalTo(detailScrollView.snp.trailing).offset(12.scale375())
            make.centerY.equalTo(detailLabel)
            make.height.equalTo(30.scale375())
        }

        separatorView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.equalTo(1.scale375())
            make.height.equalTo(12.scale375())
        }

        rightLabel.snp.makeConstraints { make in
            make.leading.equalTo(separatorView.snp.trailing).offset(8.scale375())
            make.centerY.equalToSuperview()
        }
    }

    @objc private func handleRightComponentsTap() {
        onRightComponentsTapped?()
    }
    
    @objc private func handleSliderValueChanged() {
        onSliderValueChanged?(slider.value)
    }

    private func updateConstraintsForSlider(hasSlider: Bool) {
        contentView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(hasSlider ? 96.scale375() : 66.scale375())
        }
        
        if hasSlider {
            contentView.addSubview(slider)
            rightComponentsView.addSubview(arrowIcon)
            contentView.addSubview(volumeLabel)
            
            volumeLabel.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(-16.scale375())
                make.width.equalTo(30.scale375())
                make.top.equalTo(detailLabel.snp.bottom).offset(12.scale375())
                make.height.equalTo(20.scale375())
            }
            
            slider.snp.makeConstraints { make in
                make.leading.equalTo(titleLabel)
                make.trailing.equalTo(volumeLabel.snp.leading).offset(-4.scale375())
                make.centerY.equalTo(volumeLabel)
                make.height.equalTo(20.scale375())
            }
            
            arrowIcon.snp.makeConstraints { make in
                make.leading.equalTo(rightLabel.snp.trailing)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(16.scale375())
                make.trailing.equalToSuperview()
            }
        }
    }
    
    func configure(with type: NetWorkInfoItemViewType, showDetail: Bool = true) {
        self.type = type

        switch type {
            case .video:
                titleLabel.text = .videoStatus
                detailLabel.text = .smoothStreaming
                rightLabel.text = nil
                iconView.image = internalImage("live_networkinfo_video")
                iconView.tintColor = .greenColor
            case .audio:
                titleLabel.text = .audioStatus
                detailLabel.text = .properVolume
                rightLabel.text = nil
                iconView.image = internalImage("live_networkinfo_mic")
                iconView.tintColor = .greenColor
            case .temperature:
                titleLabel.text = .deviceTemp
                detailLabel.text = .regularChecks
                iconView.image = internalImage("live_networkinfo_temp")
                iconView.tintColor = .greenColor
            case .network:
                titleLabel.text = .wifiMobile
                detailLabel.text = .avoidSwitching
                iconView.image = internalImage("live_networkinfo_wifi")
                iconView.tintColor = .greenColor
        }

        rightComponentsView.isHidden = !showDetail
        let shouldShowSlider = type == .audio && showDetail
        slider.isHidden = !shouldShowSlider
        volumeLabel.isHidden = !shouldShowSlider
        updateConstraintsForSlider(hasSlider: shouldShowSlider)
    }

    func updateSliderValue(_ value: Float) {
        slider.value = value
        volumeLabel.text = "\(Int(value))"
    }

    func updateContent(title: String? = nil,
                       status: String? = nil,
                       detail: String? = nil,
                       rightText: String? = nil,
                       iconName: String? = nil,
                       iconColor: UIColor? = nil) {
        if let title = title {
            titleLabel.text = title
        }
        if let status = status {
            statusLabel.text = status
        }
        if let detail = detail {
            detailLabel.text = detail
        }
        if let rightText = rightText {
            rightLabel.text = rightText
        }
        if let iconName = iconName {
            iconView.image = internalImage(iconName)
        }
        if let iconColor = iconColor {
            iconView.tintColor = iconColor
        }
    }
}


fileprivate extension String {
    static let videoStatus = internalLocalized("common_video_status")
    static let audioStatus = internalLocalized("common_audio_status")
    static let deviceTemp = internalLocalized("common_device_temp")
    static let wifiMobile = internalLocalized("common_wifi_or_mobile_network")
    
    static let smoothStreaming = internalLocalized("common_video_stream_smooth")
    static let properVolume = internalLocalized("common_audio_tips_proper_volume")
    static let regularChecks = internalLocalized("common_audio_tips_regular_checks")
    static let avoidSwitching = internalLocalized("common_network_switch_tips")
}

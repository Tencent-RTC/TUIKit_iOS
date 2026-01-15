//
//  SliderCell.swift
//  TUILiveKit
//
//  Created by aby on 2024/3/21.
//

import UIKit
import Combine
import SnapKit
import AtomicX

public class SliderCell: UITableViewCell {
    public static let identifier = "SliderCell"
    private var item: SliderItem?
    private var cancellableSet: Set<AnyCancellable> = []
    
    public var title: String {
        set {
            titleLabel.text = newValue
        }
        get {
            return titleLabel.text ?? ""
        }
    }
    
    let titleLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Medium16)
        }
        label.numberOfLines = 2
        return label
    }()
    
    public let valueLabel: AtomicLabel = {
        let label = AtomicLabel("") { theme in
            LabelAppearance(textColor: theme.color.textColorPrimary,
                            font: theme.typography.Regular16)
        }
        return label
    }()
    
    public let configSlider: UISlider = {
        let view = UISlider()
        view.tintColor = .b1
        view.setThumbImage(.liveBundleImage("live_slider_icon"), for: .normal)
        return view
    }()
    
    private var isViewReady = false
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        setupStyle()
        isViewReady = true
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        self.item = nil
        cancellableSet.removeAll()
    }
    
    private func constructViewHierarchy() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(configSlider)
    }
    
    private func activateConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(valueLabel.snp.leading).offset(-24).priority(.required)
        }
        titleLabel.snp.contentCompressionResistanceHorizontalPriority = 250
        
        valueLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(configSlider.snp.leading).offset(-5)
        }
        valueLabel.snp.contentCompressionResistanceHorizontalPriority = 751
        valueLabel.snp.contentHuggingHorizontalPriority = 251
        
        configSlider.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalToSuperview()
            make.height.equalTo(24)
            make.width.equalTo(110)
        }
    }
    
    private func bindInteraction() {
        configSlider.addTarget(self, action: #selector(valueChanged(sender:)), for: .valueChanged)
        configSlider.addTarget(self, action: #selector(valueDidChanged(sender:)), for: [.touchUpInside, .touchUpOutside])
    }
    
    func setupStyle() {
        backgroundColor = .clear
        selectionStyle = .none
    }
    
    public func update(item: SettingItem) {
        guard let sliderItem = item as? SliderItem else { return }
        configSlider.value = sliderItem.currentValue
        configSlider.maximumValue = sliderItem.max
        configSlider.minimumValue = sliderItem.min
        valueLabel.text = String(format: "%.2f", sliderItem.currentValue)
        sliderItem.subscribeState?(self, &cancellableSet)
        self.item = sliderItem
    }
}

extension SliderCell {
    @objc
    func valueChanged(sender: UISlider) {
        valueLabel.text = String(format: "%.f", sender.value)
        if let item = self.item {
            item.valueChanged?(sender.value)
        }
    }
    
    @objc
    func valueDidChanged(sender: UISlider) {
        if let item = self.item {
            item(payload: sender.value)
        }
    }
}

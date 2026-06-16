//
//  LiveEntranceCollectionCell.swift
//  AppAssembly
//
//  海外版（TencentRTC）Live 模块入口页 Cell —
//  从 iOS/BusinessService/AppScene/VideoLive/ui/view/LiveMainCollectionCell 移植，
//  资源切换到 AppAssemblyBundle。
//

import SnapKit
import UIKit

final class LiveEntranceCollectionCell: UICollectionViewCell {

    static let CellID: String = "LiveEntranceCollectionCell"

    private lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = .white
        label.textAlignment = .left
        label.font = .customFont(ofSize: 20, weight: .semibold)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()

    private lazy var descLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .customFont(ofSize: 10)
        label.textColor = .white.withAlphaComponent(0.75)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        constructViewHierarchy()
        activateConstraints()
        setupViewStyle()
        isViewReady = true
    }

    private func constructViewHierarchy() {
        addSubview(backgroundImageView)
        addSubview(titleLabel)
        addSubview(descLabel)
    }

    private func activateConstraints() {
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(20.scale375())
            make.height.equalTo(28.scale375Height())
            make.width.lessThanOrEqualTo(120.scale375())
        }
        descLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(8.scale375Height())
            make.width.lessThanOrEqualTo(155.scale375())
            make.height.lessThanOrEqualTo(48.scale375Height())
        }
    }

    private func setupViewStyle() {
        layer.cornerRadius = 8.scale375()
        layer.masksToBounds = true
    }

    func config(_ item: LiveEntranceItemModel) {
        titleLabel.text = item.title
        descLabel.text = item.content
        backgroundImageView.image = AppAssemblyBundle.image(named: item.imageName)
    }
}

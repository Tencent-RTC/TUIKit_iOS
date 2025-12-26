//
//  RecentCallsCell.swift
//  Pods
//
//  Created by vincepzhang on 2025/3/3.
//

import Foundation
import UIKit
import RTCRoomEngine
import RTCCommon
import Combine
import AtomicXCore

class RecentCallsCell: UITableViewCell {
    
    private var cancellables = Set<AnyCancellable>()

    typealias TUICallRecordCallsCellMoreBtnClickedHandler = () -> Void
    var moreBtnClickedHandler: TUICallRecordCallsCellMoreBtnClickedHandler = {}
    
    private var isViewReady = false
    private var viewModel: RecentCallsCellViewModel = RecentCallsCellViewModel(CallInfo())
    
    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.font = UIFont(name: "PingFangHK-Semibold", size: 14)
        label.textAlignment = TUICoreDefineConvert.getIsRTL() ? .right : .left
        return label
    }()
    
    private let mediaTypeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let resultLabel: UILabel = {
        let label = UILabel()
        label.textColor = TUICoreDefineConvert.getTUICallKitDynamicColor(colorKey: "callkit_recents_cell_subtitle_color",
                                                                         defaultHex: "#888888")
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = TUICoreDefineConvert.getIsRTL() ? .right : .left
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.textColor = TUICoreDefineConvert.getTUICallKitDynamicColor(colorKey: "callkit_recents_cell_time_color",
                                                                         defaultHex: "#BBBBBB")
        label.font = UIFont.systemFont(ofSize: 12)
        label.textAlignment = TUICoreDefineConvert.getIsRTL() ? .left : .right
        return label
    }()
    
    private let moreButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(CallKitBundle.getBundleImage(name: "ic_recents_more"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = TUICoreDefineConvert.getTUICallKitDynamicColor(colorKey: "callkit_recents_cell_bg_color",
                                                                                     defaultHex: "#FFFFFF")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if isViewReady {
            return
        }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        avatarImageView.sd_cancelCurrentImageLoad()
        avatarImageView.image = nil
    }
    
    private func constructViewHierarchy() {
        contentView.addSubview(avatarImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(mediaTypeImageView)
        contentView.addSubview(resultLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(moreButton)
    }
    
    private func activateConstraints() {
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40)
        ])

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -20)
        ])
        
        mediaTypeImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mediaTypeImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            mediaTypeImageView.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 8),
            mediaTypeImageView.widthAnchor.constraint(equalToConstant: 19),
            mediaTypeImageView.heightAnchor.constraint(equalToConstant: 12)
        ])

        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            resultLabel.centerYAnchor.constraint(equalTo: mediaTypeImageView.centerYAnchor),
            resultLabel.leadingAnchor.constraint(equalTo: mediaTypeImageView.trailingAnchor, constant: 4),
            resultLabel.widthAnchor.constraint(equalToConstant: 100)
        ])

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: -4),
            timeLabel.widthAnchor.constraint(equalToConstant: 100)
        ])

        moreButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            moreButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            moreButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            moreButton.widthAnchor.constraint(equalToConstant: 24),
            moreButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func bindInteraction() {
        moreButton.addTarget(self, action: #selector(moreButtonClick(_:)), for: .touchUpInside)
    }
    
    func configViewModel(_ viewModel: RecentCallsCellViewModel) {
        self.viewModel = viewModel
        
        titleLabel.text = viewModel.titleLabelStr
        avatarImageView.sd_setImage(with: URL(string: viewModel.faceURL), placeholderImage: viewModel.avatarImage)
        resultLabel.text = viewModel.resultLabelStr
        timeLabel.text = viewModel.timeLabelStr
        mediaTypeImageView.image = CallKitBundle.getBundleImage(name: viewModel.mediaTypeImageStr)
        
        if viewModel.callInfo.result == .missed {
            titleLabel.textColor = UIColor.red
        } else {
            titleLabel.textColor = TUICoreDefineConvert.getTUICallKitDynamicColor(colorKey: "callkit_recents_cell_title_color",
                                                                                  defaultHex: "#000000")
        }
        
        subscribeViewModel()
    }
    
    func subscribeViewModel() {
        viewModel.$faceURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newFaceURL in
                self?.avatarImageView.sd_setImage(with: URL(string: newFaceURL), placeholderImage: self?.viewModel.avatarImage)
            }
            .store(in: &cancellables)

        viewModel.$titleLabelStr
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTitle in
                self?.titleLabel.text = newTitle
            }
            .store(in: &cancellables)

        viewModel.$avatarImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newImage in
                if self?.viewModel.faceURL.isEmpty ?? true {
                    self?.avatarImageView.image = newImage
                }
            }
            .store(in: &cancellables)
    }
    
    @objc private func moreButtonClick(_ button: UIButton) {
        moreBtnClickedHandler()
    }
}

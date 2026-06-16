//
//  BGMItemCell.swift
//  TUILiveKit
//
//  BGM list cell with play/stop button only.
//

import UIKit
import SnapKit
import AtomicX

class BGMItemCell: UITableViewCell {
    static let identifier = "BGMItemCell"

    var onStartPlay: ((BGMItem) -> Void)?
    var onStopPlay: ((BGMItem) -> Void)?

    private var item: BGMItem?

    // MARK: - Subviews

    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = .customFont(ofSize: 16)
        label.textColor = .g7
        return label
    }()

    private lazy var startPlayButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(internalImage("live_music_start_play"), for: .normal)
        button.addTarget(self, action: #selector(startPlayTapped), for: .touchUpInside)
        return button
    }()

    private lazy var stopPlayButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(internalImage("live_music_pause_play"), for: .normal)
        button.addTarget(self, action: #selector(stopPlayTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = .g3.withAlphaComponent(0.6)
        return view
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        item = nil
        onStartPlay = nil
        onStopPlay = nil
        startPlayButton.isHidden = false
        stopPlayButton.isHidden = true
    }

    // MARK: - Setup

    private func setupViews() {
        contentView.addSubview(nameLabel)
        contentView.addSubview(startPlayButton)
        contentView.addSubview(stopPlayButton)
        contentView.addSubview(separatorLine)

        startPlayButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24.scale375())
        }

        stopPlayButton.snp.makeConstraints { make in
            make.edges.equalTo(startPlayButton)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(startPlayButton.snp.leading).offset(-12.scale375())
        }

        separatorLine.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(startPlayButton)
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    // MARK: - Configure

    func configure(item: BGMItem, isPlaying: Bool) {
        self.item = item
        nameLabel.text = item.name
        startPlayButton.isHidden = isPlaying
        stopPlayButton.isHidden = !isPlaying
    }

    // MARK: - Actions

    @objc private func startPlayTapped() {
        guard let item = item else { return }
        onStartPlay?(item)
    }

    @objc private func stopPlayTapped() {
        guard let item = item else { return }
        onStopPlay?(item)
    }
}

//
//  SongListCell.swift
//  Pods
//
//  Created by ssc on 2025/8/23.
//
import UIKit
import RTCRoomEngine

class SongListCell: UITableViewCell {
    private lazy var coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 4
        imageView.clipsToBounds = true
        return imageView
    }()

    var isOwner: Bool = true

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Medium", size: 14)
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary.withAlphaComponent(0.9)
        return label
    }()

    private lazy var artistLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary.withAlphaComponent(0.55)
        return label
    }()

    private lazy var actionButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
        button.layer.cornerRadius = 12
        button.setTitle(.SongText, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        button.setTitleColor(ThemeStore.shared.colorTokens.textColorButton, for: .normal)
        button.addTarget(self, action: #selector(selectSongButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var originalButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault.withAlphaComponent(0.1)
        button.setTitle(.originalText, for: .normal)
        button.titleLabel?.font = UIFont(name: "Roboto", size: 10) ?? UIFont.systemFont(ofSize: 10)
        button.setTitleColor(ThemeStore.shared.colorTokens.buttonColorPrimaryDefault, for: .normal)
        button.layer.cornerRadius = 4
        return button
    }()

    private lazy var scoreButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = ThemeStore.shared.colorTokens.textColorSuccess.withAlphaComponent(0.1)
        button.setTitle(.scoreText, for: .normal)
        button.titleLabel?.font = UIFont(name: "Roboto", size: 10) ?? UIFont.systemFont(ofSize: 10)
        button.setTitleColor(ThemeStore.shared.colorTokens.textColorSuccess, for: .normal)
        button.layer.cornerRadius = 4
        return button
    }()

    private var musicId: String = ""
    weak var karaokeManager: KaraokeManager?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(coverImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(artistLabel)
        contentView.addSubview(actionButton)
        contentView.addSubview(originalButton)
        contentView.addSubview(scoreButton)

        coverImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16.scale375())
            make.centerY.equalToSuperview()
            make.width.height.equalTo(48.scale375())
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(coverImageView.snp.right).offset(12.scale375())
            make.top.equalTo(coverImageView.snp.top)
            make.left.equalTo(coverImageView.snp.right).offset(10.scale375())
        }

        artistLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-10.scale375())
            make.left.equalTo(coverImageView.snp.right).offset(10.scale375())
        }

        actionButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16.scale375())
            make.centerY.equalToSuperview()
            make.width.equalTo(56.scale375())
            make.height.equalTo(24.scale375())
        }

        originalButton.snp.makeConstraints { make in
            make.left.equalTo(artistLabel.snp.right).offset(6.scale375())
            make.top.equalTo(artistLabel.snp.top)
            make.height.equalTo(16.scale375())
        }

        scoreButton.snp.makeConstraints { make in
            make.left.equalTo(originalButton.snp.right).offset(4.scale375())
            make.top.equalTo(artistLabel.snp.top)
            make.height.equalTo(16.scale375())
        }

        backgroundColor = ThemeStore.shared.colorTokens.bgColorDialog
        selectionStyle = .none
    }

    func configure(with song: MusicInfo, indexPath: IndexPath, isSelected: Bool) {
        titleLabel.text = song.musicName
        artistLabel.text = song.artist
        if song.coverUrl == "" {
            coverImageView.image = UIImage.atomicXBundleImage(named: "ktv_coverUrl")
        } else {
            coverImageView.kf.setImage(with: URL(string: song.coverUrl), placeholder: UIImage.avatarPlaceholderImage)
        }
        actionButton.tag = indexPath.row
        self.musicId = song.musicId

        originalButton.snp.removeConstraints()
        scoreButton.snp.removeConstraints()
        
        if song.isOriginal && song.hasRating {
            originalButton.isHidden = false
            scoreButton.isHidden = false
            originalButton.snp.makeConstraints { make in
                make.left.equalTo(artistLabel.snp.right).offset(6.scale375())
                make.top.equalTo(artistLabel.snp.top)
                make.height.equalTo(16.scale375())
            }
            scoreButton.snp.makeConstraints { make in
                make.left.equalTo(originalButton.snp.right).offset(6.scale375())
                make.top.equalTo(artistLabel.snp.top)
                make.height.equalTo(16.scale375())
            }
        } else if song.hasRating {
            originalButton.isHidden = true
            scoreButton.isHidden = false
            scoreButton.snp.makeConstraints { make in
                make.left.equalTo(artistLabel.snp.right).offset(6.scale375())
                make.top.equalTo(artistLabel.snp.top)
                make.height.equalTo(16.scale375())
            }
        } else {
            originalButton.isHidden = true
            scoreButton.isHidden = true
        }
        
        if !isOwner {
            actionButton.isHidden = true
            return
        }

        updateActionButtonState(isSelected: isSelected)
        layoutIfNeeded()
    }

    private func updateActionButtonState(isSelected: Bool) {
        if isSelected {
            actionButton.setTitle(.orderedText, for: .normal)
            actionButton.backgroundColor = .clear
            actionButton.layer.borderWidth = 1
            actionButton.layer.borderColor = ThemeStore.shared.colorTokens.strokeColorPrimary.cgColor
            actionButton.setTitleColor(ThemeStore.shared.colorTokens.textColorSecondary, for: .normal)
            actionButton.removeTarget(self, action: #selector(selectSongButtonTapped), for: .touchUpInside)
        } else {
            actionButton.setTitle(.SongText, for: .normal)
            actionButton.backgroundColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
            actionButton.layer.borderWidth = 0
            actionButton.setTitleColor(ThemeStore.shared.colorTokens.textColorButton, for: .normal)
            actionButton.addTarget(self, action: #selector(selectSongButtonTapped), for: .touchUpInside)
        }
    }

    @objc private func selectSongButtonTapped() {
        guard let karaokeManager = karaokeManager else {return}
        let userInfo = TUIRoomEngine.getSelfInfo()

        let songInfo = TUISongInfo()
        songInfo.songId = musicId

        if let musicData = karaokeManager.karaokeState.songLibrary.first(where: { $0.musicId == musicId }) {
            songInfo.songName = musicData.musicName
            songInfo.artistName = musicData.artist
            songInfo.duration = UInt(musicData.duration)
            songInfo.coverUrl = String(musicData.coverUrl)
        }

        songInfo.requester.userId = userInfo.userId
        songInfo.requester.userName = userInfo.userName
        songInfo.requester.avatarUrl = userInfo.avatarUrl
        karaokeManager.addSong(songInfo: songInfo)
    }
    
}

fileprivate extension String {
    static var orderedText: String = ("karaoke_ordered").atomicLocalized
    static var orderedCountText: String = ("karaoke_ordered_count").atomicLocalized
    static var exitOrder: String = ("karaoke_exit_order").atomicLocalized
    static var SongText: String = ("karaoke_order_song").atomicLocalized
    static var originalText: String = ("karaoke_original").atomicLocalized
    static var scoreText: String = ("karaoke_score").atomicLocalized
}


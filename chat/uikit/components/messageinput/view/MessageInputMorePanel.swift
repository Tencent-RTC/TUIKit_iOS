import UIKit
import SnapKit

protocol MessageInputMorePanelDelegate: AnyObject {
    func morePanelDidSelectAlbum()
    func morePanelDidSelectCamera()
    func morePanelDidSelectVideo()
    func morePanelDidSelectFile()
    func morePanelDidSelectVideoCall()
    func morePanelDidSelectAudioCall()
}

final class MessageInputMorePanel: UIView {
    weak var delegate: MessageInputMorePanelDelegate?

    var bottomSafeAreaInset: CGFloat = 0 {
        didSet {
            guard bottomSafeAreaInset != oldValue else { return }
            collectionBottomConstraint?.update(inset: Self.panelPadding + bottomSafeAreaInset)
        }
    }

    private let config: MessageInputConfigProtocol

    fileprivate static let columns = 4

    fileprivate static let iconSize: CGFloat = 56

    fileprivate static let iconTileCornerRadius: CGFloat = CGFloat(RadiusScheme.alertRadius)

    fileprivate static let iconGlyphSize: CGFloat = 28

    fileprivate static let titleTopSpacing: CGFloat = CGFloat(SpacingScheme.iconTextSpacing)

    fileprivate static let titleAreaHeight: CGFloat = 29

    fileprivate static let itemVerticalSpacing: CGFloat = CGFloat(SpacingScheme.smallSpacing)

    fileprivate static let panelPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    private let collectionView: UICollectionView

    private var collectionBottomConstraint: Constraint?

    private var actions: [MessageInputMenuAction] = []

    init(config: MessageInputConfigProtocol) {
        self.config = config
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = Self.itemVerticalSpacing * 2
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        setupActions()
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupActions() {
        var defaults: [MessageInputMenuAction] = [
            MessageInputMenuAction(
                ID: MessageInputActionIDs.album,
                title: LocalizedChatString("MorePhoto"),
                iconName: "more_picture",
                onClick: { [weak self] in self?.delegate?.morePanelDidSelectAlbum() }
            )
        ]
        if config.isShowPhotoTaker {
            defaults.append(MessageInputMenuAction(
                ID: MessageInputActionIDs.takePhoto,
                title: LocalizedChatString("MoreCamera"),
                iconName: "more_camera",
                onClick: { [weak self] in self?.delegate?.morePanelDidSelectCamera() }
            ))
            defaults.append(MessageInputMenuAction(
                ID: MessageInputActionIDs.recordVideo,
                title: LocalizedChatString("MoreVideo"),
                iconName: "more_video",
                onClick: { [weak self] in self?.delegate?.morePanelDidSelectVideo() }
            ))
        }
        defaults.append(MessageInputMenuAction(
            ID: MessageInputActionIDs.file,
            title: LocalizedChatString("MoreFile"),
            iconName: "more_file",
            onClick: { [weak self] in self?.delegate?.morePanelDidSelectFile() }
        ))
        if config.isShowVideoCall {
            defaults.append(MessageInputMenuAction(
                ID: MessageInputActionIDs.videoCall,
                title: LocalizedChatString("MoreVideoCall"),
                iconName: "more_video_call",
                onClick: { [weak self] in self?.delegate?.morePanelDidSelectVideoCall() }
            ))
        }
        if config.isShowAudioCall {
            defaults.append(MessageInputMenuAction(
                ID: MessageInputActionIDs.audioCall,
                title: LocalizedChatString("MoreVoiceCall"),
                iconName: "more_voice_call",
                onClick: { [weak self] in self?.delegate?.morePanelDidSelectAudioCall() }
            ))
        }
        if let customizer = config.actionCustomizer {
            let editor = CustomEditor(items: defaults)
            customizer(editor)
            actions = editor.build()
        } else {
            actions = defaults
        }
    }

    private func setupView() {
        backgroundColor = TUIChatKitTheme.colors.bgColorOperate
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(MorePanelCell.self, forCellWithReuseIdentifier: MorePanelCell.reuseID)
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(Self.panelPadding)
            collectionBottomConstraint = make.bottom.equalToSuperview()
                .inset(Self.panelPadding).constraint
        }
    }
}

// MARK: - UICollectionViewDataSource

extension MessageInputMorePanel: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return actions.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MorePanelCell.reuseID, for: indexPath
        ) as! MorePanelCell
        let item = actions[indexPath.item]
        cell.configure(icon: item.icon ?? AtomicXChatResources.image(named: item.iconName), title: item.title)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension MessageInputMorePanel: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        actions[indexPath.item].onClick()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension MessageInputMorePanel: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let availableWidth = collectionView.bounds.width
        let itemWidth = floor(availableWidth / CGFloat(Self.columns))
        let itemHeight = Self.iconSize + Self.titleTopSpacing + Self.titleAreaHeight + Self.itemVerticalSpacing
        return CGSize(width: itemWidth, height: itemHeight)
    }
}

// MARK: - MorePanelCell

private final class MorePanelCell: UICollectionViewCell {
    static let reuseID = "MorePanelCell"

    private let iconTileView = UIView()

    private let iconImageView = UIImageView()

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon: UIImage?, title: String) {
        iconImageView.image = icon
        titleLabel.text = title
    }

    private func setupCell() {
        let colors = TUIChatKitTheme.colors

        iconTileView.backgroundColor = colors.bgColorInput
        iconTileView.layer.cornerRadius = MessageInputMorePanel.iconTileCornerRadius
        iconTileView.layer.masksToBounds = true
        contentView.addSubview(iconTileView)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = colors.textColorPrimary
        iconTileView.addSubview(iconImageView)

        titleLabel.font = FontScheme.caption3Regular
        titleLabel.textColor = colors.textColorSecondary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        contentView.addSubview(titleLabel)

        iconTileView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.height.equalTo(MessageInputMorePanel.iconSize)
        }

        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(MessageInputMorePanel.iconGlyphSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconTileView.snp.bottom).offset(MessageInputMorePanel.titleTopSpacing)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(MessageInputMorePanel.titleAreaHeight)
        }
    }
}

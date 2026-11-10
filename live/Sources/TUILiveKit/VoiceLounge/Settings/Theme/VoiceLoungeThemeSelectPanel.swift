import SnapKit
import UIKit

final class VoiceLoungeThemeSelectPanel: BottomSheetView {
    var onSelect: ((String) -> Void)?
    var onSelectSkin: ((String) -> Void)?

    private let skinSectionLabel = LiveText.voiceLounge(.metadata, tone: .secondary)
    private let skinRow = UIStackView()
    private let bgSectionLabel = LiveText.voiceLounge(.metadata, tone: .secondary)
    private let collectionView: UICollectionView

    private let skins = VoiceLoungeSkin.all
    private let backgrounds = VoiceLoungeBackground.all
    private var skinSwatches: [SkinSwatch] = []

    private var selectedID = VoiceLoungeBackground.defaultID
    private var selectedSkinID = VoiceLoungeSkin.defaultID

    override var sheetHeight: CGFloat { ThemePanelStyle.sheetHeight }

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = ThemePanelStyle.cardSize
        layout.minimumLineSpacing = ThemePanelStyle.cardSpacing
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupStyles()
        setupBindings()
    }

    func bind(selectedID: String, skinID: String) {
        self.selectedID = selectedID
        self.selectedSkinID = skinID
        collectionView.reloadData()
        syncSkinSelection()
    }

    private func setupViews() {
        contentView.addSubview(skinSectionLabel)
        contentView.addSubview(skinRow)
        skinSwatches = skins.map { skin in
            let swatch = SkinSwatch(skin: skin)
            swatch.onTap = { [weak self] id in self?.selectSkin(id) }
            skinRow.addArrangedSubview(swatch)
            return swatch
        }
        contentView.addSubview(bgSectionLabel)
        contentView.addSubview(collectionView)
    }

    private func setupConstraints() {
        skinSectionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(ThemePanelStyle.sectionInset)
            make.top.equalToSuperview().offset(ThemePanelStyle.skinLabelTop)
        }
        skinRow.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(ThemePanelStyle.sectionInset)
            make.top.equalTo(skinSectionLabel.snp.bottom).offset(8)
            make.height.equalTo(ThemePanelStyle.skinRowHeight)
        }
        bgSectionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(ThemePanelStyle.sectionInset)
            make.top.equalTo(skinRow.snp.bottom).offset(16)
        }
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(bgSectionLabel.snp.bottom).offset(10)
            make.height.equalTo(ThemePanelStyle.cardSize.height)
        }
    }

    private func setupStyles() {
        sheetTitle = .themeTitle
        skinSectionLabel.text = .sectionSkin
        skinRow.axis = .horizontal
        skinRow.distribution = .fillEqually
        skinRow.alignment = .fill
        bgSectionLabel.text = .sectionBackground
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(BackgroundCell.self, forCellWithReuseIdentifier: BackgroundCell.reuseID)
        syncSkinSelection()
    }

    private func setupBindings() {}

    private func selectSkin(_ id: String) {
        guard id != selectedSkinID else { return }
        selectedSkinID = id
        syncSkinSelection()
        onSelectSkin?(id)
    }

    private func syncSkinSelection() { skinSwatches.forEach { $0.isSelected = $0.skinID == selectedSkinID } }
}

extension VoiceLoungeThemeSelectPanel: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        backgrounds.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell =
            collectionView.dequeueReusableCell(withReuseIdentifier: BackgroundCell.reuseID, for: indexPath)
            as? BackgroundCell ?? BackgroundCell()
        let background = backgrounds[indexPath.item]
        cell.configure(background: background, isSelected: background.id == selectedID)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let background = backgrounds[indexPath.item]
        guard background.id != selectedID else { return }
        selectedID = background.id
        collectionView.reloadData()
        onSelect?(background.id)
    }
}

private final class SkinSwatch: UIControl {
    let skinID: String
    var onTap: ((String) -> Void)?

    override var isSelected: Bool {
        didSet {
            selectionBox.isHidden = !isSelected;
            nameLabel.tone = isSelected ? .primary : .secondary
        }
    }

    private let selectionBox = UIView()
    private let dotView = UIView()
    private let dotGradient = CAGradientLayer()
    private let nameLabel = LiveText.voiceLounge(.metadata, tone: .secondary, alignment: .center)

    init(skin: VoiceLoungeSkin) {
        skinID = skin.id
        super.init(frame: .zero)

        selectionBox.layer.cornerRadius = ThemePanelStyle.selectionBoxCorner
        selectionBox.layer.borderWidth = 2
        selectionBox.layer.borderColor = ThemePanelStyle.selectionBorder.cgColor
        selectionBox.isHidden = true
        selectionBox.isUserInteractionEnabled = false
        addSubview(selectionBox)

        dotGradient.colors = skin.swatchColors.map { $0.cgColor }
        dotGradient.locations = skin.swatchLocations
        dotGradient.startPoint = CGPoint(x: 0, y: 0)
        dotGradient.endPoint = CGPoint(x: 1, y: 1)
        dotView.layer.addSublayer(dotGradient)
        dotView.layer.cornerRadius = ThemePanelStyle.dotSize / 2
        dotView.clipsToBounds = true
        dotView.isUserInteractionEnabled = false
        addSubview(dotView)

        nameLabel.text = skin.displayName
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.isUserInteractionEnabled = false
        addSubview(nameLabel)

        selectionBox.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.size.equalTo(ThemePanelStyle.selectionBoxSize)
        }
        dotView.snp.makeConstraints { make in
            make.center.equalTo(selectionBox)
            make.size.equalTo(ThemePanelStyle.dotSize)
        }
        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(selectionBox.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        dotGradient.frame = dotView.bounds
    }

    @objc private func handleTap() { onTap?(skinID) }
}

private final class BackgroundCell: UICollectionViewCell {
    static let reuseID = "BackgroundCell"

    private let previewView = UIImageView()
    private let nameLabel = LiveText.voiceLounge(.metadata, tone: .secondary, alignment: .center)
    private let selectionOverlay = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewView.contentMode = .scaleAspectFill
        previewView.clipsToBounds = true
        previewView.layer.cornerRadius = 12
        previewView.layer.borderWidth = 2
        previewView.layer.borderColor = UIColor.clear.cgColor
        contentView.addSubview(previewView)

        selectionOverlay.layer.cornerRadius = 12
        selectionOverlay.layer.borderWidth = 2
        selectionOverlay.layer.borderColor = ThemePanelStyle.selectionBorder.cgColor
        selectionOverlay.isHidden = true
        selectionOverlay.isUserInteractionEnabled = false
        previewView.addSubview(selectionOverlay)

        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(nameLabel)

        previewView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(ThemePanelStyle.previewHeight)
        }
        selectionOverlay.snp.makeConstraints { make in make.edges.equalToSuperview() }
        nameLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(previewView.snp.bottom).offset(6)
        }
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(background: VoiceLoungeBackground, isSelected: Bool) {
        previewView.image = background.previewImage
        nameLabel.text = background.displayName
        nameLabel.tone = isSelected ? .primary : .secondary
        selectionOverlay.isHidden = !isSelected
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewView.image = nil
        selectionOverlay.isHidden = true
    }
}

private enum ThemePanelStyle {
    static let sectionInset: CGFloat = 16
    static let skinLabelTop: CGFloat = 66
    static let dotSize: CGFloat = 36
    static let selectionBoxSize: CGFloat = 48
    static let selectionBoxCorner: CGFloat = 14
    static let skinRowHeight: CGFloat = 48 + 6 + 15

    static let previewHeight: CGFloat = 147
    static let cardSize = CGSize(width: 68, height: 147 + 6 + 15)
    static let cardSpacing: CGFloat = 10

    static let selectionBorder = VoiceLoungeColor.prepareMid

    static let sheetHeight: CGFloat = skinLabelTop + 14 + 8 + skinRowHeight + 16 + 14 + 10 + cardSize.height + 28
}

private extension String {
    static var sectionBackground: String {
        LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.section_background")
    }
    static var sectionSkin: String { LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.section_skin") }
    static var themeTitle: String { LiveKitResources.localizedString("tuilivekit.voiceroom.prepare.theme_title") }
}

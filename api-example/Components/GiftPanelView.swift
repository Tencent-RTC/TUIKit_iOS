import UIKit
import SnapKit
import Combine
import Kingfisher
import AtomicXCore

/**
 * Gift panel component (paginated horizontal scrolling)
 *
 * APIs involved:
 * - GiftStore.create(liveID:) - create a gift management instance
 * - GiftStore.setLanguage(_:) - set the gift display language
 * - GiftStore.refreshUsableGifts(completion:) - refresh the list of available gifts
 * - GiftStore.sendGift(giftID:count:completion:) - send a gift
 * - GiftStore.state - giftstate subscription (GiftState.usableGifts)
 * - GiftStore.giftEventPublisher - giftevent subscription (GiftEvent.onReceiveGift)
 *
 * Features:
 * - Display available gifts in paginated pages (per page 2 rows x 4 columns = 8 items)
 * - Switch pages by swiping left and right, page indicator at the bottom
 * - Select and send a gift
 * - listen for received gift events
 */
class GiftPanelView: UIView {

    // MARK: - Properties

    private let liveID: String
    private lazy var giftStore = GiftStore.create(liveID: liveID)
    private var cancellables = Set<AnyCancellable>()
    private var gifts: [Gift] = []
    private var selectedGiftIndex: Int?

    /// number of rows per page
    private let rowsPerPage = 2
    /// number of columns per page
    private let columnsPerPage = 4
    /// number of gifts per page
    private var itemsPerPage: Int { rowsPerPage * columnsPerPage }

    /// callback when a gift is received (for external display such as a Toast)
    var onReceiveGift: ((Gift, UInt8, LiveUserInfo) -> Void)?
    /// gift send result callback
    var onSendGiftResult: ((Result<Void, ErrorInfo>) -> Void)?

    // MARK: - UI Components

    /// gift grid list (paginated scrolling)
    private lazy var collectionView: UICollectionView = {
        let layout = GiftPageLayout()
        layout.rowsPerPage = rowsPerPage
        layout.columnsPerPage = columnsPerPage

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.isPagingEnabled = true
        cv.delegate = self
        cv.dataSource = self
        cv.register(GiftCell.self, forCellWithReuseIdentifier: GiftCell.reuseIdentifier)
        return cv
    }()

    /// page indicator
    private let pageControl: UIPageControl = {
        let pc = UIPageControl()
        pc.currentPageIndicatorTintColor = .systemPink
        pc.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.3)
        pc.isUserInteractionEnabled = false
        return pc
    }()

    /// send gift button
    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("interactive.gift.send".localized, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.backgroundColor = .systemPink
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 16
        return button
    }()

    // MARK: - Init

    init(liveID: String) {
        self.liveID = liveID
        super.init(frame: .zero)
        setupUI()
        setupBindings()
        setupActions()
        loadGifts()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear

        addSubview(collectionView)
        addSubview(pageControl)
        addSubview(sendButton)

        collectionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(200)
        }

        pageControl.snp.makeConstraints { make in
            make.top.equalTo(collectionView.snp.bottom)
            make.centerX.equalToSuperview()
            make.height.equalTo(20)
        }

        sendButton.snp.makeConstraints { make in
            make.top.equalTo(pageControl.snp.bottom).offset(4)
            make.trailing.equalToSuperview().offset(-12)
            make.width.equalTo(80)
            make.height.equalTo(32)
            make.bottom.equalToSuperview().offset(-8)
        }
    }

    private func setupBindings() {
        // Subscribe to gift list state changes
        giftStore.state.subscribe()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.gifts = state.usableGifts.flatMap { $0.giftList }
                let totalPages = max(1, Int(ceil(Double(self.gifts.count) / Double(self.itemsPerPage))))
                self.pageControl.numberOfPages = totalPages
                self.collectionView.reloadData()
            }
            .store(in: &cancellables)

        // Subscribe to incoming gift events
        giftStore.giftEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .onReceiveGift(_, let gift, let count, let sender):
                    self?.onReceiveGift?(gift, count, sender)
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func setupActions() {
        sendButton.addTarget(self, action: #selector(sendGiftTapped), for: .touchUpInside)
    }

    // MARK: - Data Loading

    /// Load the list of available gifts
    private func loadGifts() {
        // Set the display language
//        let language = LocalizedManager.shared.isChinese ? "zh-CN" : "en"
//        giftStore.setLanguage(language)

        // Refresh the gift list
        giftStore.refreshUsableGifts { [weak self] result in
            switch result {
            case .success:
                break
            case .failure(let error):
                self?.onSendGiftResult?(.failure(error))
            }
        }
    }

    // MARK: - Actions

    /// Send the selected gift
    @objc private func sendGiftTapped() {
        guard let index = selectedGiftIndex, index < gifts.count else { return }
        let gift = gifts[index]

        giftStore.sendGift(giftID: gift.giftID, count: 1) { [weak self] result in
            DispatchQueue.main.async {
                self?.onSendGiftResult?(result)
            }
        }
    }
}

// MARK: - UICollectionViewDataSource & Delegate

extension GiftPanelView: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return gifts.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GiftCell.reuseIdentifier, for: indexPath) as? GiftCell else {
            return UICollectionViewCell()
        }
        let gift = gifts[indexPath.item]
        cell.configure(with: gift, isSelected: indexPath.item == selectedGiftIndex)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedGiftIndex = indexPath.item
        collectionView.reloadData()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }
        let currentPage = Int(round(scrollView.contentOffset.x / pageWidth))
        pageControl.currentPage = currentPage
    }
}

// MARK: - GiftPageLayout

/// Custom paginated layout: a rows x columns grid per page with horizontal pagination
private class GiftPageLayout: UICollectionViewLayout {

    var rowsPerPage = 2
    var columnsPerPage = 4
    var itemSpacing: CGFloat = 8
    var sectionInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

    private var itemsPerPage: Int { rowsPerPage * columnsPerPage }
    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentWidth: CGFloat = 0

    override func prepare() {
        super.prepare()
        cachedAttributes.removeAll()

        guard let collectionView, collectionView.numberOfSections > 0 else { return }

        let totalItems = collectionView.numberOfItems(inSection: 0)
        guard totalItems > 0 else { return }

        let pageWidth = collectionView.bounds.width
        let pageHeight = collectionView.bounds.height
        let totalPages = Int(ceil(Double(totalItems) / Double(itemsPerPage)))

        // Calculate the size of a single item
        let availableWidth = pageWidth - sectionInset.left - sectionInset.right - CGFloat(columnsPerPage - 1) * itemSpacing
        let itemWidth = floor(availableWidth / CGFloat(columnsPerPage))
        let availableHeight = pageHeight - sectionInset.top - sectionInset.bottom - CGFloat(rowsPerPage - 1) * itemSpacing
        let itemHeight = floor(availableHeight / CGFloat(rowsPerPage))

        for index in 0..<totalItems {
            let page = index / itemsPerPage
            let positionInPage = index % itemsPerPage
            let row = positionInPage / columnsPerPage
            let column = positionInPage % columnsPerPage

            let x = CGFloat(page) * pageWidth + sectionInset.left + CGFloat(column) * (itemWidth + itemSpacing)
            let y = sectionInset.top + CGFloat(row) * (itemHeight + itemSpacing)

            let indexPath = IndexPath(item: index, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
            cachedAttributes.append(attributes)
        }

        contentWidth = CGFloat(totalPages) * pageWidth
    }

    override var collectionViewContentSize: CGSize {
        guard let collectionView else { return .zero }
        return CGSize(width: contentWidth, height: collectionView.bounds.height)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.item < cachedAttributes.count else { return nil }
        return cachedAttributes[indexPath.item]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return true }
        return collectionView.bounds.size != newBounds.size
    }
}

// MARK: - GiftCell

/// Gift cell - displays the gift icon, name, and price
private class GiftCell: UICollectionViewCell {

    static let reuseIdentifier = "GiftCell"

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    /// price container (coin icon + price text)
    private let priceStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .center
        return stack
    }()

    private let coinIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "bitcoinsign.circle.fill")
        imageView.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Gold coin color
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Gold coin color
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.15)

        priceStack.addArrangedSubview(coinIcon)
        priceStack.addArrangedSubview(priceLabel)

        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(priceStack)

        iconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(6)
            make.width.height.equalTo(40)
        }

        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(4)
        }

        coinIcon.snp.makeConstraints { make in
            make.width.height.equalTo(12)
        }

        priceStack.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(2)
            make.centerX.equalToSuperview()
        }
    }

    func configure(with gift: Gift, isSelected: Bool) {
        nameLabel.text = gift.name
        priceLabel.text = "\(gift.coins)"

        // Use Kingfisher to load the gift icon
        let placeholder = UIImage(systemName: "gift.fill")
        iconImageView.kf.setImage(
            with: URL(string: gift.iconURL),
            placeholder: placeholder,
            options: [
                .transition(.fade(0.2)),
                .cacheOriginalImage,
            ]
        )

        // Selected state: higher-contrast background + border + highlighted name
        if isSelected {
            contentView.backgroundColor = UIColor.systemPink.withAlphaComponent(0.25)
            contentView.layer.borderWidth = 1.5
            contentView.layer.borderColor = UIColor.systemPink.cgColor
            nameLabel.textColor = .white
        } else {
            contentView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            contentView.layer.borderWidth = 0
            contentView.layer.borderColor = nil
            nameLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        }
    }
}

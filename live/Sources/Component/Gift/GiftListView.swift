//
//  GiftListView.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/1/2.
//

import AtomicXCore
import Combine
import RTCRoomEngine
import SnapKit
import TUICore
import AtomicX

public protocol GiftListViewDelegate: AnyObject {
    func giftListView(_ view: GiftListView, cellClassFor gift: Gift) -> UICollectionViewCell.Type?
    
    func giftListView(_ view: GiftListView, configureCustomCell cell: UICollectionViewCell, for gift: Gift)
    
    func giftListViewHeaderRightView(_ view: GiftListView) -> UIView?
    
    func giftListViewBottomView(_ view: GiftListView) -> UIView?
    
    func giftListView(_ view: GiftListView, didSelect gift: Gift)
    
    func giftListView(_ view: GiftListView, didSend gift: Gift, count: UInt, result: Result<Void, ErrorInfo>)
}

public extension GiftListViewDelegate {
    func giftListView(_ view: GiftListView, cellClassFor gift: Gift) -> UICollectionViewCell.Type? { return nil }
    func giftListView(_ view: GiftListView, configureCustomCell cell: UICollectionViewCell, for gift: Gift) {}
    func giftListViewHeaderRightView(_ view: GiftListView) -> UIView? { return nil }
    func giftListViewBottomView(_ view: GiftListView) -> UIView? { return nil }
    func giftListView(_ view: GiftListView, didSelect gift: Gift) {}
    func giftListView(_ view: GiftListView, didSend gift: Gift, count: Int, result: Result<Void, Error>) {}
}

public class GiftListView: UIView {
    
    // MARK: - Public Properties
    public weak var delegate: GiftListViewDelegate? {
        didSet {
            refreshSlots()
        }
    }
    
    // MARK: - Private Properties
    private let liveId: String
    private lazy var store: GiftStore = {
        return GiftStore.create(liveID: liveId)
    }()
    
    // Data Source
    private var giftCategories: [GiftCategory] = []
    private var currentSelectedCategoryIndex: Int = 0
    private var currentSelectedCellIndex: IndexPath = .init(row: 0, section: 0)
    private var cancellableSet: Set<AnyCancellable> = []
    
    // Layout Config
    private var rows: Int = 2
    private var itemSize: CGSize = .init(width: 74, height: 74 + 53)
    
    // MARK: - UI Components
    
    private lazy var topContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var categoryTabView: UICollectionView = {
        let layout = GiftCollectionViewLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 0
        
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.register(GiftCategoryTabCell.self, forCellWithReuseIdentifier: GiftCategoryTabCell.reuseIdentifier)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.delegate = self
        view.dataSource = self
        return view
    }()
    
    private lazy var headerRightContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = .flowKitWhite.withAlphaComponent(0.25)
        return view
    }()
    
    private lazy var flowLayout: TUIGiftSideslipLayout = {
        let layout = TUIGiftSideslipLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = itemSize
        layout.rows = rows
        return layout
    }()
    
    private lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.bounds, collectionViewLayout: self.flowLayout)
        if #available(iOS 11.0, *) {
            view.contentInsetAdjustmentBehavior = .never
        }
        view.isPagingEnabled = false
        view.scrollsToTop = true
        view.delegate = self
        view.dataSource = self
        view.showsVerticalScrollIndicator = true
        view.showsHorizontalScrollIndicator = false
        view.backgroundColor = .clear
        return view
    }()
    
    private lazy var bottomContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    // MARK: - Init
    
    public init(roomId: String) {
        self.liveId = roomId
        super.init(frame: .zero)
        addObserver()
        setupUI()
        var language = getPreferredLanguage()
        if language != "en", language != "zh-Hans", language != "zh-Hant" {
            language = "en"
        }
        store.setLanguage(language)
        store.refreshUsableGifts(completion: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        removeObserver()
    }

    private var isViewReady = false
    override public func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
    }
}

// MARK: - Special config

public extension GiftListView {
    func setRows(rows: Int) {
        if flowLayout.rows != rows {
            flowLayout.rows = rows
            collectionView.reloadData()
        }
    }

    func setItemSize(itemSize: CGSize) {
        if flowLayout.itemSize == itemSize {
            flowLayout.itemSize = itemSize
            collectionView.reloadData()
        }
    }
}

// MARK: - Private functions

extension GiftListView {
    private func setupUI() {
        addSubview(topContainer)
        topContainer.addSubview(categoryTabView)
        topContainer.addSubview(headerRightContainer)
        
        addSubview(separatorLine)
        addSubview(collectionView)
        addSubview(bottomContainer)
        
        topContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
        }
        
        headerRightContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
        
        categoryTabView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().offset(10)
        }
        
        separatorLine.snp.makeConstraints { make in
            make.top.equalTo(topContainer.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(0.5)
        }
        
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(separatorLine.snp.bottom).offset(10)
            make.leading.trailing.bottom.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(200.scale375())
        }
        
        bottomContainer.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
            make.height.equalTo(0)
        }
        
        addSwipeGestures()
    }
    
    private func refreshSlots() {
        headerRightContainer.subviews.forEach { $0.removeFromSuperview() }
        if let rightView = delegate?.giftListViewHeaderRightView(self) {
            headerRightContainer.addSubview(rightView)
            rightView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        bottomContainer.subviews.forEach { $0.removeFromSuperview() }
        bottomContainer.snp.remakeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            if let bottomView = delegate?.giftListViewBottomView(self) {
                bottomContainer.addSubview(bottomView)
                bottomView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
            } else {
                make.height.equalTo(0)
            }
        }
    }
    
    // MARK: - Data Logic
    
    private func addObserver() {
        store.state.subscribe(StatePublisherSelector(keyPath: \GiftState.usableGifts))
            .receive(on: RunLoop.main)
            .sink { [weak self] categories in
                guard let self = self else { return }
                self.giftCategories = categories
                self.handleDataUpdate()
            }
            .store(in: &cancellableSet)
    }
    
    
    private func removeObserver() {
        cancellableSet.forEach { $0.cancel() }
        cancellableSet.removeAll()
    }
    
    private func handleDataUpdate() {
        categoryTabView.reloadData()
        collectionView.reloadData()
        
        if !giftCategories.isEmpty {
            if currentSelectedCategoryIndex >= giftCategories.count {
                selectCategory(at: 0)
            } else {
                selectCategory(at: currentSelectedCategoryIndex)
            }
        }
    }
    
    private func selectCategory(at index: Int) {
        guard index < giftCategories.count else { return }
        
        currentSelectedCategoryIndex = index
        currentSelectedCellIndex = .init(row: 0, section: 0)
        
        categoryTabView.reloadData()
        categoryTabView.layoutIfNeeded()
        
        let indexPath = IndexPath(item: index, section: 0)
        categoryTabView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        
        collectionView.reloadData()
    }
    
    private var currentGiftList: [Gift] {
        guard currentSelectedCategoryIndex < giftCategories.count else { return [] }
        return giftCategories[currentSelectedCategoryIndex].giftList
    }
    
    // MARK: - Swipe Gestures
    
    private func addSwipeGestures() {
        let left = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        left.direction = .left
        collectionView.addGestureRecognizer(left)
        
        let right = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        right.direction = .right
        collectionView.addGestureRecognizer(right)
    }
    
    @objc private func handleSwipeGesture(_ gesture: UISwipeGestureRecognizer) {
        guard !giftCategories.isEmpty else { return }
        
        switch gesture.direction {
        case .left:
            let nextIndex = min(currentSelectedCategoryIndex + 1, giftCategories.count - 1)
            if nextIndex != currentSelectedCategoryIndex { selectCategory(at: nextIndex) }
        case .right:
            let prevIndex = max(currentSelectedCategoryIndex - 1, 0)
            if prevIndex != currentSelectedCategoryIndex { selectCategory(at: prevIndex) }
        default: break
        }
    }
}

// MARK: - UICollectionViewDataSource

extension GiftListView: UICollectionViewDataSource {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == categoryTabView { return giftCategories.count }
        return currentGiftList.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == categoryTabView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GiftCategoryTabCell.reuseIdentifier, for: indexPath) as! GiftCategoryTabCell
            if indexPath.item < giftCategories.count {
                cell.configure(with: giftCategories[indexPath.item], isSelected: indexPath.item == currentSelectedCategoryIndex)
            }
            return cell
        }
        
        else {
            let gift = currentGiftList[indexPath.row]
            
            var cellClass = delegate?.giftListView(self, cellClassFor: gift)

            if cellClass == nil {
                let isAdvanced = !gift.resourceURL.isEmpty
                
                if isAdvanced {
                    cellClass = GiftSingleCell.self
                } else {
                    cellClass = GiftComboCell.self
                }
            }
            
            let finalClass = cellClass ?? GiftSingleCell.self
            let reuseIdentifier = finalClass.cellReuseIdentifier
            
            collectionView.register(finalClass, forCellWithReuseIdentifier: reuseIdentifier)
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
            
            if let baseCell = cell as? GiftBaseCell {
                baseCell.giftInfo = gift
                baseCell.delegate = self
                baseCell.isSelected = (indexPath == currentSelectedCellIndex)
                
                delegate?.giftListView(self, configureCustomCell: baseCell, for: gift)
            }
            
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegate

extension GiftListView: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == categoryTabView {
            selectCategory(at: indexPath.item)
            return
        }
        
        if indexPath == currentSelectedCellIndex {
            return
        }
        
        let preIndex = currentSelectedCellIndex
        currentSelectedCellIndex = indexPath
        
        if let oldCell = collectionView.cellForItem(at: preIndex) {
            oldCell.isSelected = false
        }
        
        let gift = currentGiftList[indexPath.row]
        if let newCell = collectionView.cellForItem(at: currentSelectedCellIndex) {
            newCell.isSelected = true
            delegate?.giftListView(self, didSelect: gift)
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension GiftListView: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == categoryTabView {
            let category = giftCategories[indexPath.item]
            let font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
            let width = category.name.size(withAttributes: [.font: font]).width
            return CGSize(width: max(width + 20, 50), height: 44)
        } else {
            return itemSize
        }
    }
}

// MARK: - GiftCellDelegate 实现

extension GiftListView: GiftCellDelegate {
    
    public func cell(_ cell: UICollectionViewCell, onSend gift: Gift, count: UInt) {
        DataReporter.reportEventData(eventKey: getReportKey())
        
        store.sendGift(giftID: gift.giftID, count: UInt(count)) { [weak self] result in
            guard let self = self else { return }
            
            self.delegate?.giftListView(self, didSend: gift, count: count, result: result)
            
            if case .failure(let error) = result {
                 print("Send Gift Error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: DataReport

private extension GiftListView {
    private func getReportKey() -> Int {
        let isSupportEffectPlayer = isSupportEffectPlayer()
        var key = Constants.DataReport.kDataReportLiveGiftSVGASendCount
        switch DataReporter.componentType {
        case .liveRoom:
            key = isSupportEffectPlayer ? Constants.DataReport.kDataReportLiveGiftEffectSendCount :
                Constants.DataReport.kDataReportLiveGiftSVGASendCount
        case .voiceRoom:
            key = isSupportEffectPlayer ? Constants.DataReport.kDataReportVoiceGiftEffectSendCount :
                Constants.DataReport.kDataReportVoiceGiftSVGASendCount
        default:
            break
        }
        return key
    }

    private func isSupportEffectPlayer() -> Bool {
        let service = TUICore.getService("TUIEffectPlayerService")
        return service != nil
    }
}

// MARK: - GiftCategoryTabCell

private class GiftCategoryTabCell: UICollectionViewCell {
    static let reuseIdentifier = "GiftCategoryTabCell"
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "PingFangSC-Regular", size: 14)
        label.textAlignment = .center
        label.textColor = .flowKitWhite.withAlphaComponent(0.55)
        return label
    }()
    
    private lazy var indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .flowKitWhite
        view.layer.cornerRadius = 2
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        addSubview(indicatorView)
        
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        indicatorView.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.equalTo(0)
            make.height.equalTo(2)
        }
    }
    
    func configure(with category: GiftCategory, isSelected: Bool) {
        titleLabel.text =  category.name
        titleLabel.textColor = isSelected ? .flowKitWhite : .flowKitWhite.withAlphaComponent(0.55)
        indicatorView.isHidden = !isSelected
        
        if isSelected {
            let textWidth = titleLabel.intrinsicContentSize.width
            indicatorView.snp.updateConstraints { make in
                make.width.equalTo(textWidth)
            }
        } else {
            indicatorView.snp.updateConstraints { make in
                make.width.equalTo(0)
            }
        }
    }
}

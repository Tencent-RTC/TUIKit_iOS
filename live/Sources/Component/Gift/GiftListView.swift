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

public class GiftListView: UIView {
    private let liveId: String
    private var store: GiftStore {
        GiftStore.create(liveID: liveId)
    }

    // MARK: - 数据源
    private var giftCategories: [GiftCategory] = []
    private var currentSelectedCategoryIndex: Int = 0
    private var currentSelectedCellIndex: IndexPath = .init(row: 0, section: 0)
    private var cancellableSet: Set<AnyCancellable> = []

    // MARK: - UI配置
    private var rows: Int = 2
    private var itemSize: CGSize = .init(width: 74, height: 74 + 53)

    // MARK: - UI组件
    private lazy var categoryTabView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
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
        view.register(TUIGiftCell.self, forCellWithReuseIdentifier: TUIGiftCell.cellReuseIdentifier)
        view.isPagingEnabled = false
        view.scrollsToTop = true
        view.delegate = self
        view.dataSource = self
        view.showsVerticalScrollIndicator = true
        view.showsHorizontalScrollIndicator = false
        view.backgroundColor = .clear
        return view
    }()

    public init(roomId: String) {
        self.liveId = roomId
        super.init(frame: .zero)
        addObserver()
        setupUI()
        var language = TUIGlobalization.getPreferredLanguage() ?? "en"
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
        addSubview(categoryTabView)
        addSubview(separatorLine)
        addSubview(collectionView)
        
        categoryTabView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().offset(10)
            make.height.equalTo(44)
        }
        
        separatorLine.snp.makeConstraints { make in
            make.top.equalTo(categoryTabView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(0.5)
        }
        
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(separatorLine.snp.bottom).offset(10)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        addSwipeGestures()
    }
    
    private func addSwipeGestures() {
        let leftSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        leftSwipeGesture.direction = .left
        collectionView.addGestureRecognizer(leftSwipeGesture)
        
        let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        rightSwipeGesture.direction = .right
        collectionView.addGestureRecognizer(rightSwipeGesture)
    }
    
    @objc private func handleSwipeGesture(_ gesture: UISwipeGestureRecognizer) {
        guard !giftCategories.isEmpty else { return }
        
        switch gesture.direction {
        case .left:
            let nextIndex = min(currentSelectedCategoryIndex + 1, giftCategories.count - 1)
            if nextIndex != currentSelectedCategoryIndex {
                selectCategory(at: nextIndex)
            }
        case .right:
            let prevIndex = max(currentSelectedCategoryIndex - 1, 0)
            if prevIndex != currentSelectedCategoryIndex {
                selectCategory(at: prevIndex)
            }
        default:
            break
        }
    }

    private func addObserver() {
        store.state.subscribe(StatePublisherSelector(keyPath: \GiftState.usableGifts))
            .receive(on: RunLoop.main)
            .sink { [weak self] categories in
                guard let self = self else { return }
                giftCategories = categories
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    categoryTabView.reloadData()
                    collectionView.reloadData()
                    collectionView.layoutIfNeeded()
                    
                    if !giftCategories.isEmpty {
                        selectCategory(at: 0)
                    }
                }
            }
            .store(in: &cancellableSet)
    }

    private func removeObserver() {
        cancellableSet.forEach { $0.cancel() }
        cancellableSet.removeAll()
    }
    
    private func selectCategory(at index: Int) {
        guard index < giftCategories.count else { return }
        
        currentSelectedCategoryIndex = index
        currentSelectedCellIndex = .init(row: 0, section: 0)
        
        categoryTabView.reloadData()
        
        let indexPath = IndexPath(item: index, section: 0)
        categoryTabView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        
        if !currentGiftList.isEmpty {
            collectionView.selectItem(at: currentSelectedCellIndex, animated: false, scrollPosition: [])
        }
    }
    
    private var currentGiftList: [Gift] {
        guard currentSelectedCategoryIndex < giftCategories.count else { return [] }
        return giftCategories[currentSelectedCategoryIndex].giftList
    }
}

// MARK: UICollectionViewDelegate

extension GiftListView: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == categoryTabView {
            selectCategory(at: indexPath.item)
        } else {
            let preSelectedCellIndex = currentSelectedCellIndex
            currentSelectedCellIndex = indexPath
            if let cell = collectionView.cellForItem(at: preSelectedCellIndex) as? TUIGiftCell {
                cell.isSelected = false
            }
            if let cell = collectionView.cellForItem(at: currentSelectedCellIndex) as? TUIGiftCell {
                cell.isSelected = true
            }
        }
    }
}

// MARK: UICollectionViewDataSource

extension GiftListView: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == categoryTabView {
            return giftCategories.count
        } else {
            return currentGiftList.count
        }
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == categoryTabView {
            let reuseCell = collectionView.dequeueReusableCell(withReuseIdentifier: GiftCategoryTabCell.reuseIdentifier, for: indexPath)
            guard let cell = reuseCell as? GiftCategoryTabCell else { return reuseCell }
            
            if indexPath.item < giftCategories.count {
                let category = giftCategories[indexPath.item]
                cell.configure(with: category, isSelected: indexPath.item == currentSelectedCategoryIndex)
            }
            
            return cell
        } else {
            let reuseCell = collectionView.dequeueReusableCell(withReuseIdentifier: TUIGiftCell.cellReuseIdentifier, for: indexPath)
            guard let cell = reuseCell as? TUIGiftCell else { return reuseCell }
            
            if indexPath.row < currentGiftList.count {
                let giftInfo = currentGiftList[indexPath.row]
                cell.giftInfo = giftInfo
                cell.sendBlock = { [weak self, weak cell] giftInfo in
                    if let self = self {
                        DataReporter.reportEventData(eventKey: getReportKey())
                        store.sendGift(giftID: giftInfo.giftID, count: 1) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case .failure(let error):
                                let err = InternalError(code: error.code, message: error.message)
                                GiftManager.shared.toastSubject.send(err.localizedMessage)
                            default: break
                            }
                        }
                    }
                    if let cell = cell {
                        cell.isSelected = false
                    }
                }
            }
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension GiftListView: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == categoryTabView {
            let category = giftCategories[indexPath.item]
            let font = UIFont(name: "PingFangSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
            let textWidth = category.name.size(withAttributes: [.font: font]).width
            return CGSize(width: max(textWidth + 20, 50), height: 44)
        } else {
            return itemSize
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

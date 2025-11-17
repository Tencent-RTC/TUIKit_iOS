//
//  AvatarSelectorViewController.swift
//  TIMCommon
//
//  Created by AI Assistant on 2025/10/10.
//  Copyright © 2025 Tencent. All rights reserved.
//

import UIKit
import SDWebImage

class AvatarSelectorViewController: UIViewController {
    
    // MARK: - Properties
    var selectCallback: ((String?) -> Void)?
    var selectAvatarType: AvatarSelectorType = .userAvatar
    var profileFaceURL: String?
    var cacheGroupGridAvatarImage: UIImage?
    var createGroupType: String?
    
    // MARK: - Private Properties
    private var titleView: UILabel!
    private var collectionView: UICollectionView!
    private var dataArray: [AvatarCardItem] = []
    private var currentSelectCardItem: AvatarCardItem? {
        didSet {
            updateRightButton()
        }
    }
    private var rightButton: UIButton!
    
    private let reuseIdentifier = "AvatarCollectionCell"
    
    // MARK: - Constants
    private let userAvatarCount = 20
    private let groupAvatarCount = 15
    private let backgroundCoverCount = 10
    private let communityCoverCount = 8
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigator()
        loadData()
    }
    
    // MARK: - Private Methods
    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground
        
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = UIColor.systemGroupedBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(AvatarCollectionCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        view.addSubview(collectionView)
        
        // Auto Layout
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupNavigator() {
        // Title
        let titleText: String
        switch selectAvatarType {
        case .cover:
            titleText = "选择封面"
        case .conversationBackgroundCover:
            titleText = "选择背景"
        default:
            titleText = "选择头像"
        }
        title = titleText
        
        // Right button
        rightButton = UIButton(type: .system)
        rightButton.setTitle("保存", for: .normal)
        rightButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        rightButton.setTitleColor(.gray, for: .normal)
        rightButton.addTarget(self, action: #selector(rightBarButtonClick), for: .touchUpInside)
        
        let rightItem = UIBarButtonItem(customView: rightButton)
        navigationItem.rightBarButtonItem = rightItem
    }
    
    private func loadData() {
        dataArray.removeAll()
        
        switch selectAvatarType {
        case .userAvatar:
            for i in 1...userAvatarCount {
                let cardItem = createCardItem(byURL: getUserAvatarURL(i))
                dataArray.append(cardItem)
            }
            
        case .groupAvatar:
            // Add group grid avatar if enabled
            if let cacheImage = cacheGroupGridAvatarImage {
                let cardItem = createGroupGridAvatarCardItem()
                dataArray.append(cardItem)
            }
            
            for i in 1...groupAvatarCount {
                let cardItem = createCardItem(byURL: getGroupAvatarURL(i))
                dataArray.append(cardItem)
            }
            
        case .conversationBackgroundCover:
            let cleanCardItem = createCleanCardItem()
            dataArray.append(cleanCardItem)
            
            for i in 1...backgroundCoverCount {
                let cardItem = createCardItem(byURL: getBackgroundCoverURL(i), 
                                            fullURL: getBackgroundCoverFullURL(i))
                dataArray.append(cardItem)
            }
            
        case .cover:
            for i in 1...communityCoverCount {
                let cardItem = createCardItem(byURL: getCommunityCoverURL(i))
                dataArray.append(cardItem)
            }
        }
        
        collectionView.reloadData()
    }
    
    private func createCardItem(byURL urlString: String) -> AvatarCardItem {
        let cardItem = AvatarCardItem()
        cardItem.posterUrlStr = urlString
        cardItem.isSelect = false
        
        if cardItem.posterUrlStr == profileFaceURL {
            cardItem.isSelect = true
            currentSelectCardItem = cardItem
        }
        
        return cardItem
    }
    
    private func createCardItem(byURL urlString: String, fullURL: String) -> AvatarCardItem {
        let cardItem = AvatarCardItem()
        cardItem.posterUrlStr = urlString
        cardItem.fullUrlStr = fullURL
        cardItem.isSelect = false
        
        if cardItem.posterUrlStr == profileFaceURL || cardItem.fullUrlStr == profileFaceURL {
            cardItem.isSelect = true
            currentSelectCardItem = cardItem
        }
        
        return cardItem
    }
    
    private func createGroupGridAvatarCardItem() -> AvatarCardItem {
        let cardItem = AvatarCardItem()
        cardItem.posterUrlStr = nil
        cardItem.isSelect = false
        cardItem.isGroupGridAvatar = true
        cardItem.createGroupType = createGroupType
        cardItem.cacheGroupGridAvatarImage = cacheGroupGridAvatarImage
        
        if profileFaceURL == nil {
            cardItem.isSelect = true
            currentSelectCardItem = cardItem
        }
        
        return cardItem
    }
    
    private func createCleanCardItem() -> AvatarCardItem {
        let cardItem = AvatarCardItem()
        cardItem.posterUrlStr = nil
        cardItem.isSelect = false
        cardItem.isDefaultBackgroundItem = true
        
        if profileFaceURL?.isEmpty != false {
            cardItem.isSelect = true
            currentSelectCardItem = cardItem
        }
        
        return cardItem
    }
    
    private func updateRightButton() {
        if currentSelectCardItem != nil {
            rightButton.setTitleColor(.systemBlue, for: .normal)
        } else {
            rightButton.setTitleColor(.gray, for: .normal)
        }
    }
    
    @objc private func rightBarButtonClick() {
        guard let currentItem = currentSelectCardItem else { return }
        
        if selectAvatarType == .conversationBackgroundCover {
            if let fullURL = currentItem.fullUrlStr, !fullURL.isEmpty {
                // Show loading
                showLoadingToast()
                
                // Prefetch image
                SDWebImagePrefetcher.shared.prefetchURLs([URL(string: fullURL)].compactMap { $0 }) { [weak self] _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self?.hideLoadingToast()
                        self?.showSuccessToast("背景设置成功")
                        self?.selectCallback?(currentItem.fullUrlStr)
                        self?.navigationController?.popViewController(animated: true)
                    }
                }
            } else {
                showSuccessToast("背景设置成功")
                selectCallback?(currentItem.fullUrlStr)
                navigationController?.popViewController(animated: true)
            }
        } else {
            selectCallback?(currentItem.posterUrlStr)
            navigationController?.popViewController(animated: true)
        }
    }
    
    private func recoverSelectedStatus() {
        guard let currentItem = currentSelectCardItem else { return }
        
        if let index = dataArray.firstIndex(of: currentItem) {
            currentItem.isSelect = false
            let indexPath = IndexPath(row: index, section: 0)
            
            if let cell = collectionView.cellForItem(at: indexPath) as? AvatarCollectionCell {
                cell.updateSelectedUI()
            } else {
                collectionView.layoutIfNeeded()
                if let cell = collectionView.cellForItem(at: indexPath) as? AvatarCollectionCell {
                    cell.updateSelectedUI()
                }
            }
        }
    }
    
    // MARK: - URL Generators (Mock implementations)
    private func getUserAvatarURL(_ index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_\(index).png"
    }
    
    private func getGroupAvatarURL(_ index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/group-avatar/group_avatar_\(index).png"
    }
    
    private func getBackgroundCoverURL(_ index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/conversation-backgroundImage/backgroundImage_\(index).png"
    }
    
    private func getBackgroundCoverFullURL(_ index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/conversation-backgroundImage/backgroundImage_\(index)_full.png"
    }
    
    private func getCommunityCoverURL(_ index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/community-cover/community_cover_\(index).png"
    }
    
    // MARK: - Toast Methods (Mock implementations)
    private func showLoadingToast() {
        // Implementation for loading toast
    }
    
    private func hideLoadingToast() {
        // Implementation for hiding loading toast
    }
    
    private func showSuccessToast(_ message: String) {
        // Implementation for success toast
    }
}

// MARK: - UICollectionViewDataSource
extension AvatarSelectorViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! AvatarCollectionCell
        
        if indexPath.row < dataArray.count {
            cell.cardItem = dataArray[indexPath.row]
        }
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension AvatarSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        recoverSelectedStatus()
        
        guard let cell = collectionView.cellForItem(at: indexPath) as? AvatarCollectionCell else {
            collectionView.layoutIfNeeded()
            guard let cell = collectionView.cellForItem(at: indexPath) as? AvatarCollectionCell else { return }
            handleCellSelection(cell)
            return
        }
        
        handleCellSelection(cell)
    }
    
    private func handleCellSelection(_ cell: AvatarCollectionCell) {
        guard let cardItem = cell.cardItem else { return }
        
        if currentSelectCardItem == cardItem {
            currentSelectCardItem = nil
        } else {
            cardItem.isSelect = true
            cell.updateSelectedUI()
            currentSelectCardItem = cardItem
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension AvatarSelectorViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let margin: CGFloat = 15
        let padding: CGFloat = 13
        
        let rowCount: CGFloat = (selectAvatarType == .cover || selectAvatarType == .conversationBackgroundCover) ? 2.0 : 4.0
        let width = (view.frame.width - 2 * margin - (rowCount - 1) * padding) / rowCount
        let height: CGFloat = (selectAvatarType == .conversationBackgroundCover) ? 125 : 77
        
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 24, left: 15, bottom: 0, right: 15)
    }
}

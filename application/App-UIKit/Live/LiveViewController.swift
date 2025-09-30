//
//  LiveViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/8.
//

import UIKit
import TUICore

class LiveViewController: UIViewController {

    private var menuItems: [LiveMainItemModel] = []

    private lazy var collectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.sectionInset = UIEdgeInsets(top: 20.scale375Height(), left: 20.scale375(), bottom: 0, right: 20.scale375())
        flowLayout.minimumLineSpacing = 16.scale375Height()
        flowLayout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.register(LiveMainCollectionCell.self,
                                forCellWithReuseIdentifier: LiveMainCollectionCell.CellID)
        collectionView.backgroundColor = UIColor.clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = true
        collectionView.isPagingEnabled = true
        return collectionView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        initMenuData()
        setupNavigation()
        constructViewHierarchy()
        activateConstraints()
        view.backgroundColor = .white
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
}

// MARK: - Private
extension LiveViewController {

    private func initMenuData() {
        menuItems = [
            LiveMainItemModel(imageName: "main_item_video_live", title: .videoLiveTitle, content: .videoLiveDesc),
            LiveMainItemModel(imageName: "main_item_voice_room", title: .voiceRoomTitle, content: .voiceRoomDesc),
        ]
    }

    private func constructViewHierarchy() {
        view.addSubview(collectionView)
    }

    private func activateConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupNavigation() {
        navigationItem.title = .liveTitle
    }
}

// MARK: - UICollectionViewDataSource
extension LiveViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return menuItems.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LiveMainCollectionCell.CellID,
                                                      for: indexPath) as! LiveMainCollectionCell
        cell.config(menuItems[indexPath.row])
        return cell
    }

}

// MARK: - UICollectionViewDelegate
extension LiveViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item == 0 {
            let controller = VideoLiveViewController()
            navigationController?.pushViewController(controller, animated: true)
        } else if indexPath.item == 1 {
            let controller = VoiceRoomViewController()
            navigationController?.pushViewController(controller, animated: true)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 335.scale375(), height: 180.scale375Height())
    }
}

// MARK: - Localized String
private extension String {
    static let liveTitle = "live".localized
    static let videoLiveTitle = "Video Live".localized
    static let videoLiveDesc = "Create Interactive Video Live with Live API for a Seamless Streaming Experience.".localized
    static let voiceRoomTitle = "Voice Room".localized
    static let voiceRoomDesc = "Enable Interactive Voice Room with Live API for an Enhanced Communication Experience.".localized
    static let KTVRoomTitle = "KTV".localized
    static let KTVRoomDesc = "Enable Interactive KTV Room with Live API for an Enhanced Communication Experience.".localized
}

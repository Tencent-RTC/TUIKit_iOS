//
//  LiveEntranceViewController.swift
//  AppAssembly
//
//  `LiveListViewController` / `VoiceRoomViewController`。
//

import SnapKit
import UIKit

// MARK: - LiveEntranceViewController

final class LiveEntranceViewController: UIViewController {

    private var menuItems: [LiveEntranceItemModel] = []

    private lazy var collectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.sectionInset = UIEdgeInsets(top: 20.scale375Height(),
                                               left: 20.scale375(),
                                               bottom: 0,
                                               right: 20.scale375())
        flowLayout.minimumLineSpacing = 16.scale375Height()
        flowLayout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.register(LiveEntranceCollectionCell.self,
                                forCellWithReuseIdentifier: LiveEntranceCollectionCell.CellID)
        collectionView.backgroundColor = .clear
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

// MARK: - Setup

private extension LiveEntranceViewController {

    func initMenuData() {
        menuItems = [
            LiveEntranceItemModel(imageName: "main_item_video_live",
                                  title: LiveLocalize("assembly_over_seas_live_title"),
                                  content: LiveLocalize("assembly_over_seas_live_subtitle")),
            LiveEntranceItemModel(imageName: "main_item_voice_room",
                                  title: LiveLocalize("assembly_over_seas_voice_room_title"),
                                  content: LiveLocalize("assembly_over_seas_voice_room_subtitle")),
        ]
    }

    func constructViewHierarchy() {
        view.addSubview(collectionView)
    }

    func activateConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupNavigation() {
        navigationItem.title = LiveLocalize("assembly_live_card_title")

        let helpButton = UIButton(type: .custom)
        helpButton.setImage(AppAssemblyBundle.image(named: "help_small"), for: .normal)
        helpButton.addTarget(self, action: #selector(helpClick), for: .touchUpInside)
        helpButton.sizeToFit()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: helpButton)

        let backBtn = UIButton(type: .custom)
        backBtn.setImage(AppAssemblyBundle.image(named: "home_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        backBtn.sizeToFit()
        let backItem = UIBarButtonItem(customView: backBtn)
        backItem.tintColor = .white
        navigationItem.leftBarButtonItem = backItem
    }
}

// MARK: - Actions

private extension LiveEntranceViewController {

    @objc func helpClick() {
        let isRTCube = Bundle.main.bundleIdentifier == "com.tencent.mrtc"
        let urlStr = isRTCube
            ? "https://cloud.tencent.com/document/product/647/105441"
            : "https://trtc.io/document/60036?product=live&menulabel=uikit&platform=ios"
        guard let url = URL(string: urlStr) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    @objc func backBtnClick() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension LiveEntranceViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return menuItems.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LiveEntranceCollectionCell.CellID,
                                                      for: indexPath) as! LiveEntranceCollectionCell
        cell.config(menuItems[indexPath.row])
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension LiveEntranceViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let target: UIViewController
        if indexPath.item == 0 {
            target = LiveListViewController()
        } else {
            target = VoiceRoomViewController()
        }
        navigationController?.pushViewController(target, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 335.scale375(), height: 180.scale375Height())
    }
}

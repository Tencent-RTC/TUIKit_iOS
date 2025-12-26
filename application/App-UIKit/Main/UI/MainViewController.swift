//
//  MainViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/7.
//

import UIKit
import ImSDK_Plus
import TUICore
import RTCCommon
import TUICallKit_Swift
import SensorsAnalyticsSDK
import Kingfisher
import AtomicXCore
import TUIRoomKit

private let mainMenuItemColors = [
    UIColor(red: 204/255.0, green: 223/255.0, blue: 255/255.0, alpha: 1),
    UIColor(red: 204/255.0, green: 223/255.0, blue: 255/255.0, alpha: 0.3),
    UIColor(red: 204/255.0, green: 223/255.0, blue: 255/255.0, alpha: 0)
]

class MainViewController: UIViewController {
    private var mainMenuItems: [MainMenuItemModel] = []
    private lazy var mainView: MainView = {
        let mainView = MainView(frame: .zero)
        mainView.delegate = self
        return mainView
    }()
    
    lazy var collectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        flowLayout.itemSize = CGSize(width: screenWidth / 2 - 12, height: 106)
        flowLayout.minimumLineSpacing = 0
        flowLayout.minimumInteritemSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = UIColor.clear
        collectionView.isScrollEnabled = true
        collectionView.isPagingEnabled = true
        return collectionView
    }()
    
    private lazy var mineCenterBtn: UIButton = {
        let button = UIButton(type: .custom)
        button.layer.cornerRadius = 16
        button.clipsToBounds = true
        return button
    }()
    
    private func configData() {
        mainMenuItems = [
            MainMenuItemModel(imageName: "main_call",
                              title: "call".localized,
                              content: "callContent".localized,
                              gradientColors: mainMenuItemColors,
                              selectHandle: { [weak self] in
                                  guard let self = self else { return }
                                  self.gotoCallView()
                                  self.trackSensorData("video_call")
                              }),
            MainMenuItemModel(imageName: "main_live",
                              title: "live".localized,
                              content: "liveContent".localized,
                              gradientColors: mainMenuItemColors,
                              selectHandle: { [weak self] in
                                  guard let self = self else { return }
                                  self.gotoLiveView()
                                  self.trackSensorData("live_streaming")
                              }),
            MainMenuItemModel(imageName: "main_room",
                              title: "tuiRoom".localized,
                              content: "tuiRoomContent".localized,
                              gradientColors: mainMenuItemColors,
                              selectHandle: { [weak self] in
                                  guard let self = self else { return }
                                  self.gotoRoomView()
                                  self.trackSensorData("conference")
                              }),
        ]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configData()
        view.backgroundColor = UIColor(red: 235, green: 237, blue: 245)
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        updateMineCenterImage()
    }
    
    @objc private func handleUserProfileChanged(_ notification: Notification) {
        updateMineCenterImage()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
        updateMineCenterImage()
    }
}

extension MainViewController {
    private func constructViewHierarchy() {
        view.addSubview(mainView)
        view.addSubview(collectionView)
    }
    
    private func activateConstraints() {
        let statusBarHeight = statusBarHeight()
        mainView.snp.makeConstraints { make in
            make.top.equalTo(view).offset(statusBarHeight)
            make.height.equalTo(44.scale375Height())
            make.leading.equalTo(view).offset(20.scale375Width())
            make.trailing.equalTo(view).offset(-20.scale375Width())
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(mainView.snp.bottom).offset(12.scale375Height())
            make.leading.trailing.equalTo(view)
            make.bottom.equalTo(view)
        }
    }
    
    private func bindInteraction() {
        TUICSToastManager.setDefaultPosition(TUICSToastPositionCenter)
        collectionView.register(MainCollectionCell.self,forCellWithReuseIdentifier: "MainCollectionCell")
        collectionView.delegate = self
        collectionView.dataSource = self
    }
}

extension MainViewController {
    
    func gotoCallView() {
        let enterCallVC = CallViewController()
        enterCallVC.title = "call".localized
        enterCallVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(enterCallVC, animated: true)
    }
    
    func gotoLiveView() {
        let enterLiveVC = LiveViewController()
        navigationController?.pushViewController(enterLiveVC, animated: true)
    }
    
    func gotoRoomView() {
//        let enterRoomVC = ConferenceOptionsViewController()
//        self.navigationController?.pushViewController(enterRoomVC, animated: true)
        let roomHomeViewController = RoomHomeViewController()
        self.navigationController?.pushViewController(roomHomeViewController, animated: true)
    }
    
}

extension MainViewController {
    func trackSensorData(_ sensor: String) {
        SensorsAnalyticsSDK.sharedInstance()?.track("app_uikit_main_click_event", withProperties: ["main" : sensor])
    }
}

extension MainViewController {
    func updateMineCenterImage() {
        guard let userId = LoginStore.shared.state.value.loginUserInfo?.userID, !userId.isEmpty else {
            mainView.updateIconImage(with: UIImage(named: "default_avatar")!)
            return
        }
        let faceUrl = LoginStore.shared.state.value.loginUserInfo?.avatarURL
        if let avatarURL = faceUrl, !avatarURL.isEmpty {
            loadAvatarImage(from: avatarURL)
        } else {
            mainView.updateIconImage(with: UIImage(named: "default_avatar")!)
        }
    }
    
    private func loadAvatarImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            mainView.updateIconImage(with: UIImage(named: "default_avatar")!)
            return
        }
        KingfisherManager.shared.retrieveImage(with: url) { [weak self] result in
            switch result {
            case .success(let imageResult):
                self?.mainView.updateIconImage(with: imageResult.image)
            case .failure:
                self?.mainView.updateIconImage(with: UIImage(named: "default_avatar")!)
            }
        }
    }
}


extension MainViewController: MainViewDelegate {
    func jumpProfileController() {
        let mineView = MineViewController()
        navigationController?.pushViewController(mineView, animated: true)
    }
    
}

extension MainViewController: UICollectionViewDataSource{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mainMenuItems.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MainCollectionCell",
                                                      for: indexPath) as! MainCollectionCell
        cell.setupDefaultConfig(mainMenuItems[indexPath.row])
        return cell
    }
}

extension MainViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        mainMenuItems[indexPath.row].selectHandle()
    }
}

extension MainViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: screenWidth / 2 - 13, height: 106)
    }
}

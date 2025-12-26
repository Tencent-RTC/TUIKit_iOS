//
//  ConferenceOptionsViewController.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/20.
//

import UIKit
import RTCRoomEngine
import Combine
import TUIRoomKit

class ConferenceOptionsViewController: UIViewController {
    private var cancellableSet = Set<AnyCancellable>()
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let optionsView = view as? ConferenceOptionsView else {
            return
        }
        UIApplication.shared.isIdleTimerDisabled = false
        navigationController?.setNavigationBarHidden(true, animated: false)
        optionsView.reloadConferenceList()
    }
        
    override func loadView() {
        let view = ConferenceOptionsView(viewController: self)
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        ConferenceSession.sharedInstance.enableWaterMark()
    }
    
    deinit {
        debugPrint("deinit \(self)")
    }
}

extension ConferenceOptionsViewController {
    func didBackButtonClicked(in optionsView: ConferenceOptionsView) {
        if let navigationController = self.navigationController {
            if navigationController.viewControllers.first != self {
                navigationController.popViewController(animated: true)
            } else if presentingViewController != nil {
                navigationController.dismiss(animated: true, completion: nil)
            }
        } else if presentingViewController != nil {
            dismiss(animated: true, completion: nil)
        }

    }
    
    func joinRoom() {
        navigationController?.pushViewController(RoomViewController(), animated: true)
    }
    
    func createRoom() {
        navigationController?.pushViewController(CreateRoomViewController(), animated: true)
    }
    
    func scheduleRoom() {
//        let scheduleViewController = ScheduleConferenceViewController()
//        navigationController?.pushViewController(scheduleViewController, animated: true)
    }
}

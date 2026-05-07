//
//  CallingBotHesitationViewController.swift
//  main
//

import UIKit
import AtomicX
import Alamofire
import TUICallKit_Swift
import RTCRoomEngine
import TUICore

enum CallBotType: Int {
    case initCall
    case hostCall
}

fileprivate class CallingCustomView: UIView {
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        roundedRect(.allCorners, withCornerRatio: 10.0)
    }
}

class CallingBotHesitationViewController: UIViewController {
    private var callType: CallBotType = .initCall
    var virtualRobotList: [CallingRequestRobotModel?] = []
    var callBotIsBusyHandle: () -> Void = {}
    var callBotFailedHandle: (_ message: String) -> Void = { _ in }
    var requestBotHandler: (_ botID: String) -> Void = { _ in }
    var waitingCallBotFailedHandle: (_ message: String) -> Void = { _ in }

    private let containerView: UIView = {
        let view = CallingCustomView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()

    private let avarImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let tipsLable: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = CallingLocalize("Demo.TRTC.calling.WakupRobot")
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        label.font = ThemeStore.shared.typographyTokens.Medium12
        return label
    }()

    private let cancelCallingButton: UIButton = {
        let button = UIButton(type: .custom)
        button.layer.borderColor = ThemeStore.shared.colorTokens.textColorError.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = ThemeStore.shared.borderRadius.radius16
        button.layer.masksToBounds = true
        button.setTitleColor(ThemeStore.shared.colorTokens.textColorError, for: .normal)
        button.setTitle(CallingLocalize("Demo.TRTC.calling.cancel"), for: .normal)
        return button
    }()

    func configRobotAvatar(avatarImage: UIImage) {
        self.avarImageView.image = avatarImage
    }

    convenience init(callType: CallBotType) {
        self.init()
        self.callType = callType
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 235, green: 237, blue: 245)
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(AppAssemblyBundle.image(named: "calling_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = UIColor.black
        navigationItem.leftBarButtonItem = item
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        self.perform(#selector(postRequest), with: nil, afterDelay: 2)
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
}

extension CallingBotHesitationViewController {
    private func constructViewHierarchy() {
        view.addSubview(containerView)
        containerView.addSubview(avarImageView)
        containerView.addSubview(tipsLable)
        containerView.addSubview(cancelCallingButton)
    }

    private func activateConstraints() {
        containerView.snp.makeConstraints { make in
            make.topMargin.equalToSuperview().offset(100)
            make.left.equalToSuperview().offset(54)
            make.height.equalTo(352)
            make.centerX.equalToSuperview()
        }
        avarImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(54)
            make.centerX.equalToSuperview()
            make.height.equalTo(84)
            make.width.equalTo(84)
        }
        tipsLable.snp.makeConstraints { make in
            make.top.equalTo(avarImageView.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
        cancelCallingButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-54)
            make.centerX.equalToSuperview()
            make.height.equalTo(32)
            make.width.equalTo(100)
        }
    }

    func bindInteraction() {
        cancelCallingButton.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
    }
}

extension CallingBotHesitationViewController {
    @objc func backBtnClick() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        self.navigationController?.popViewController(animated: true)
    }
}

extension CallingBotHesitationViewController {
    @objc private func postRequest() {
        if self.callType == .initCall {
            self.initCallBot()
        } else {
            self.hostCallBot()
        }
    }
}

extension CallingBotHesitationViewController {
    private func initCallBot() {
        HTTPRequstBotService.requestInitCallBot { [weak self] botjson in
            guard let self = self else { return }
            let requestModel = self.convertJsonToModel(json: botjson)
            if requestModel?.errorCode == 0 {
                guard let botModelData = requestModel?.data else { return }
                guard let botModelArray = botModelData.virtualUsers else { return }
                if botModelArray.count > 0 {
                    let callIndex = Int.random(in: 0 ... botModelArray.count - 1)
                    printClog("[AppCall][initCallBot]callIndex:\(callIndex)")
                    guard let callID = botModelArray[callIndex]?.virtualUserId else { return }
                    printClog("[AppCall][initCallBot]callID:\(callID)")
                    self.requestBotHandler(callID)
                } else {
                    self.callBotIsBusyHandle()
                }
            } else {
                printClog("[AppCall][initCallBot] requestSuccessButResultErr:\(String(describing: requestModel?.errorCode))")
                self.view.makeToast(CallingLocalize("Demo.TRTC.calling.unexpectedErr"))
            }
            self.navigationController?.popViewController(animated: true)
        } failed: { [weak self] message in
            guard let self = self else { return }
            print(message)
            self.callBotFailedHandle(message)
            self.navigationController?.popViewController(animated: true)
        }
    }

    private func hostCallBot() {
        HTTPRequstBotService.requestWattingCall {
        } failed: { [weak self] message in
            guard let self = self else { return }
            print(message)
            self.waitingCallBotFailedHandle(message)
        }
        navigationController?.popViewController(animated: true)
    }
}

extension CallingBotHesitationViewController {
    func convertJsonToModel(json: [String: Any]) -> CallingRequestRobotModel? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
            let decoder = JSONDecoder()
            let model = try decoder.decode(CallingRequestRobotModel.self, from: jsonData)
            return model
        } catch let error {
            print("转换失败: \(error)")
            return nil
        }
    }
}

extension CallingBotHesitationViewController {
    private func printClog(_ log: String) {
//        TRTCCloud.sharedInstance().apiLog(log)
        debugPrint(log)
    }
}

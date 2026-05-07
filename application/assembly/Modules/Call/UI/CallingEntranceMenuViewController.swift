//
//  CallingEntranceMenuViewController.swift
//  main
//

import UIKit
import Toast_Swift
import TUICallKit_Swift
import Login
import RTCRoomEngine
import TUICore
import AtomicXCore
import AtomicX

class CallingFooterView: UIView {
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        roundedRect([.bottomLeft, .bottomRight], withCornerRatio: 10)
    }
}

public class CallingEntranceMenuViewController: UIViewController {
    var listViewDidScrollCallback: ((UIScrollView) -> Void)?
    private var CallingMenuItems: [CallingMenuModel] = []
    private var CallingRobotItems: [CallingRobotModel] = []
    private lazy var tableView: UITableView = {
        var table = UITableView(frame: .zero, style: .grouped)
        table.isScrollEnabled = false
        table.dataSource = self
        table.delegate = self
        table.backgroundColor = UIColor.clear
        table.estimatedRowHeight = 120
        table.sectionFooterHeight = 10
        table.rowHeight = UITableView.automaticDimension
        table.showsVerticalScrollIndicator = false
        table.register(CallingRobotCell.self, forCellReuseIdentifier: CallingRobotCell.reuseId)
        table.separatorColor = .clear
        return table
    }()

    private let historyButton: UIButton = {
        let button = UIButton(type: .custom)
        return button
    }()

    private let selectLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.text = CallingLocalize("Demo.TRTC.calling.callingSelectTitle")
        label.font = ThemeStore.shared.typographyTokens.Medium12
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        return label
    }()

    private let historyContentView: UIView = {
        let view = UIView(frame: .zero)
        view.isHidden = true
        return view
    }()

    private let historybuttonLabel: UILabel = {
        let label = UILabel(frame: .zero)
        let text = NSMutableAttributedString(string:
            CallingLocalize("Demo.TRTC.calling.callingHistory"))
        if let image = AppAssemblyBundle.image(named: "calling_call_pushArrow") {
            let imageAttachment = NSTextAttachment()
            imageAttachment.image = image
            let font = ThemeStore.shared.typographyTokens.Medium14
            let imageAttachmentY = round(font.capHeight - image.size.height) / 2.0
            imageAttachment.bounds = CGRect(x: 4,
                                            y: imageAttachmentY,
                                            width: image.size.width,
                                            height: image.size.height)

            let imageString = NSAttributedString(attachment: imageAttachment)
            text.append(imageString)
            label.font = font
        }
        label.attributedText = text
        label.textColor = ThemeStore.shared.colorTokens.buttonColorPrimaryDefault
        label.textAlignment = .center
        return label
    }()

    func configData() {
        CallingMenuItems = [
            CallingMenuModel(title: CallingLocalize("Demo.TRTC.Calling.robotCalling"),
                             content: CallingLocalize("Demo.TRTC.Calling.robotCallingContent"),
                             imageName: "calling_unfold_arrow",
                             stressContent: [
                                 CallingLocalize("Demo.TRTC.calling.RobotStressString"),
                             ],
                             selectHandle: { [weak self] in
                                 guard let self = self else { return }
                                 self.updateBotCells()
                             }),
            CallingMenuModel(title: CallingLocalize("Demo.TRTC.Calling.humanCalling"),
                             content: CallingLocalize("Demo.TRTC.Calling.humanCallingContent"),
                             imageName: "calling_call_pushArrow",
                             stressContent: [
                                 CallingLocalize("Demo.TRTC.calling.callTwoHumanStress"),
                             ],
                             selectHandle: { [weak self] in
                                 guard let self = self else { return }
                                 self.gotoCallingContactVC()
                             }),
        ]
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 235, green: 237, blue: 245)
        let backBtn = UIButton(type: .custom)
        backBtn.setImage(AppAssemblyBundle.image(named: "calling_back"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        let item = UIBarButtonItem(customView: backBtn)
        item.tintColor = UIColor.black
        navigationItem.leftBarButtonItem = item
        
        title = CallingLocalize("Demo.TRTC.Portal.Main.call")

        configData()
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
#if RTCube_APPSTORE
#else
        TUICore.callService(TUICore_ContactUsService,
                            method: TUICore_ContactService_ShowContactEntrance,
                            param: [:])
#endif
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TUICore.callService(TUICore_ContactUsService,
                            method: TUICore_ContactService_HideContactEntrance,
                            param: [:])
    }

    deinit {
        debugPrint("deinit \(self)")
    }
}

extension CallingEntranceMenuViewController {
    private func constructViewHierarchy() {
        view.addSubview(tableView)
        view.addSubview(historyContentView)
        view.addSubview(selectLabel)
        historyContentView.addSubview(historybuttonLabel)
        historyContentView.addSubview(historyButton)
    }

    private func activateConstraints() {
        selectLabel.snp.makeConstraints { make in
            make.topMargin.equalToSuperview().offset(20)
            make.left.equalToSuperview().offset(20)
            make.height.equalTo(18)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalTo(selectLabel.snp.bottom)
            make.left.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-100)
        }
        historyContentView.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-44)
            make.width.equalTo(131)
            make.height.equalTo(24)
            make.centerX.equalToSuperview()
        }
        historybuttonLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        historyButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func bindInteraction() {
        historyButton.addTarget(self, action: #selector(gotoHistoryVC), for: .touchUpInside)
    }
}

extension CallingEntranceMenuViewController: UITableViewDataSource, UITableViewDelegate {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return CallingRobotItems.count
        }
        return 0
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        return CallingMenuItems.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = CallingRobotCell.reuseId
        var cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! CallingRobotCell
        if cell.isEqual(nil) {
            cell = CallingRobotCell(frame: .zero)
        }
        cell.selectionStyle = .none
        cell.config(CallingRobotItems[indexPath.row])
        cell.clickedDialBotHandler = { [weak self] image, callType in
            guard let self = self else { return }
            self.gotoHesitationVC(botAvatarImage: image, callType: callType)
        }
        cell.selectionStyle = .none
        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 69
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let model = CallingMenuItems[section]
        let headerView = CallingMenuHeaderView(frame: CGRect(x: 0, y: 0, width: ScreenWidth, height: 98))
        headerView.tag = section
        headerView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didSelectSection(sender:)))
        headerView.addGestureRecognizer(tap)
        headerView.config(model)
        return headerView
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 96
    }

    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = CallingFooterView(frame: CGRect(x: 0, y: 0, width: ScreenWidth - 40, height: 10))
        footerView.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return footerView
    }

    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 10
    }

    public func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
        return 10
    }

    public func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 96
    }
}

extension CallingEntranceMenuViewController {
    @objc func didSelectSection(sender: Any) {
        let gesture = sender as! UITapGestureRecognizer
        let headerView = gesture.view as! CallingMenuHeaderView
        CallingMenuItems[headerView.tag].selectHandle()
    }

    @objc func backBtnClick() {
        self.navigationController?.popViewController(animated: true)
    }
}

extension CallingEntranceMenuViewController {
    func updateBotCells() {
        if CallingRobotItems.count == 0 && UserOverdueLogicManager.sharedManager().userOverdueState == .alreadyLogged {
            CallingRobotItems = [
                CallingRobotModel(imageName: "calling_robot_A",
                                  title: "Robot A",
                                  buttonIconImage: "calling_init_call",
                                  hasTopBorder: true, hasBotBorder: true,
                                  botCallType: .initCall),
                CallingRobotModel(imageName: "calling_robot_B",
                                  title: "Robot B", buttonIconImage: "calling_pass_call",
                                  hasTopBorder: false,
                                  hasBotBorder: false,
                                  botCallType: .hostCall),
            ]
        } else {
            CallingRobotItems.removeAll()
            if UserOverdueLogicManager.sharedManager().userOverdueState == .notLogin {
                self.view.makeToast(CallingLocalize("Demo.TRTC.Portal.Main.LoginFailed"))
            }
        }
        tableView.reloadData()
    }
}

extension CallingEntranceMenuViewController {
    func gotoHesitationVC(botAvatarImage: UIImage, callType: CallBotType) {
        let hesVC = CallingBotHesitationViewController(callType: callType)
        hesVC.configRobotAvatar(avatarImage: botAvatarImage)
        hesVC.title = CallingLocalize("Demo.TRTC.calling.call")
        hesVC.requestBotHandler = { [weak self] callID in
            let language = TUIGlobalization.getPreferredLanguage() ?? ""
            if language.contains("zh") {
                TUICallKit.createInstance().calls(userIdList: [callID],
                                                  mediaType: .video,
                                                  params: nil,
                                                  completion: nil)
            } else {
                let userDataDict: [String: Any] = ["lang": "en"]
                guard let userDataJson = (try? JSONSerialization.data(withJSONObject: userDataDict, options: []))
                    .flatMap({ String(data: $0, encoding: .utf8) }) else { return }
                var params = CallParams()
                params.userData = userDataJson
                TUICallKit.createInstance().calls(userIdList: [callID],
                                                  mediaType: .video,
                                                  params: params) { result in
                    switch result {
                    case .success():
                        break
                    case .failure(let error):
                        self?.view.makeToast("dial phone failed with code:\(error.code) msg:\(error.message)")
                    }
                }
            }
        }
        hesVC.callBotIsBusyHandle = { [weak self] in
            guard let self = self else { return }
            self.view.makeToast(CallingLocalize("Demo.TRTC.calling.callingBotIsBusy"))
        }
        hesVC.callBotFailedHandle = { [weak self] message in
            guard let self = self else { return }
            self.view.makeToast("call bot failed:\(message)")
        }
        hesVC.waitingCallBotFailedHandle = { [weak self] message in
            guard let self = self else { return }
            self.view.makeToast("waiting call bot failed:\(message)")
        }
        self.navigationController?.pushViewController(hesVC, animated: true)
    }

    func gotoCallingContactVC() {
        let videoCallVC = TRTCCallingContactViewController()
        videoCallVC.callType = .video
        videoCallVC.title = CallingLocalize("Demo.TRTC.calling.call")
        navigationController?.pushViewController(videoCallVC, animated: true)
    }

    @objc private func gotoHistoryVC() {
        let historyVC = CallingRecentCallsViewController()
        self.navigationController?.pushViewController(historyVC, animated: true)
    }
}

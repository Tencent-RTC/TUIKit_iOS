//
//  MineRootView.swift
//  mine
//

import Foundation
import Kingfisher
import SnapKit
import TUICore
import UIKit
import AtomicX

protocol MineRootViewDelegate: NSObjectProtocol {
    func goBack()
    func jumpProfileController()
    func jumpExperienceRoom()
    func logout()
}

class MineRootView: UIView {
    let viewModel: MineViewModel
    weak var delegate: MineViewController?
    
    init(viewModel: MineViewModel, frame: CGRect = .zero) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Elements
    
    private lazy var backBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setBackgroundImage(UIImage(named: "mine_goback"), for: .normal)
        btn.sizeToFit()
        return btn
    }()
    
    lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Bold16
        label.text = MineLocalize("Demo.TRTC.Portal.Mine.personalcenter")
        label.textAlignment = .center
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()
    
    lazy var bgImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "mine_bg_icon")
        return imageView
    }()
    
    let headImageDiameter: CGFloat = 72
    
    lazy var headImageView: UIImageView = {
        let imageV = UIImageView(frame: .zero)
        imageV.contentMode = .scaleAspectFill
        imageV.layer.cornerRadius = headImageDiameter / 2
        imageV.clipsToBounds = true
        return imageV
    }()
    
    lazy var userNameBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle("USERID", for: .normal)
        btn.titleLabel?.lineBreakMode = .byTruncatingTail
        btn.adjustsImageWhenHighlighted = false
        btn.setTitleColor(ThemeStore.shared.colorTokens.textColorPrimary, for: .normal)
        btn.titleLabel?.font = ThemeStore.shared.typographyTokens.Bold18
        btn.setImage(UIImage(named: "main_mine_edit"), for: .normal)
        return btn
    }()
    
    lazy var userIdLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        return label
    }()
    
    private let containerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return view
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 48, right: 0)
        tableView.isScrollEnabled = false
        return tableView
    }()
    
    #if !RTCUBE_OVERSEAS
    private let rtcExperienceRoomBtn: RTCExperienceRoomButtonView = {
        let btn = RTCExperienceRoomButtonView()
        btn.configure(
            with: MineLocalize("Demo.TRTC.Portal.Mine.quickOnlineDebug"),
            leftImageName: "main_mine_debug",
            rightImageName: "main_mine_detail"
        )
        btn.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        return btn
    }()
    #endif
    
    private lazy var logoutBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(MineLocalize("Demo.TRTC.Portal.Mine.logout"), for: .normal)
        btn.setTitleColor(ThemeStore.shared.colorTokens.textColorError, for: .normal)
        btn.titleLabel?.font = ThemeStore.shared.typographyTokens.Bold16
        btn.backgroundColor = ThemeStore.shared.colorTokens.bgColorOperate
        btn.sizeToFit()
        return btn
    }()
    
    // MARK: - Layout
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        containerView.roundedRect(rect: containerView.bounds,
                                  byRoundingCorners: .allCorners,
                                  cornerRadii: CGSize(width: 10, height: 10))
        
        #if !RTCUBE_OVERSEAS
        rtcExperienceRoomBtn.roundedRect(rect: rtcExperienceRoomBtn.bounds,
                                         byRoundingCorners: .allCorners,
                                         cornerRadii: CGSize(width: 10, height: 10))
        #endif
        logoutBtn.roundedRect(rect: logoutBtn.bounds,
                              byRoundingCorners: .allCorners,
                              cornerRadii: CGSize(width: 10, height: 10))
    }
    
    var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        backgroundColor = ThemeStore.shared.colorTokens.bgColorDefault
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
    }
    
    func constructViewHierarchy() {
        addSubview(bgImageView)
        addSubview(backBtn)
        addSubview(titleLabel)
        addSubview(headImageView)
        addSubview(userNameBtn)
        addSubview(userIdLabel)
        addSubview(containerView)
        containerView.addSubview(tableView)
        #if !RTCUBE_OVERSEAS
        addSubview(rtcExperienceRoomBtn)
        #endif
        addSubview(logoutBtn)
    }
    
    func activateConstraints() {
        let navFullHeight = navigationFullHeight()
        let statusBarH = statusBarHeight()
        
        bgImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.equalTo(ScreenWidth)
            make.height.equalTo(ScreenWidth * (112.0 / 375.0) + navFullHeight)
        }
        backBtn.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.left.equalToSuperview().offset(20)
            make.width.height.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(statusBarH)
            make.centerX.equalToSuperview()
            make.width.equalTo(ScreenWidth / 2.0)
            make.height.equalTo(44)
        }
        headImageView.snp.makeConstraints { make in
            make.bottom.centerX.equalTo(bgImageView)
            make.size.equalTo(CGSize(width: headImageDiameter, height: headImageDiameter))
        }
        userNameBtn.snp.makeConstraints { make in
            make.top.equalTo(headImageView.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.centerX.equalToSuperview()
        }
        userIdLabel.snp.makeConstraints { make in
            make.top.equalTo(userNameBtn.snp.bottom).offset(2)
            make.centerX.equalToSuperview()
        }
        containerView.snp.makeConstraints { make in
            make.top.equalTo(userIdLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(58 * viewModel.tableDataSource.count + 16)
        }
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-8)
        }
        #if !RTCUBE_OVERSEAS
        rtcExperienceRoomBtn.snp.makeConstraints { make in
            make.top.equalTo(containerView.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(60)
        }
        #endif
        
        logoutBtn.snp.makeConstraints { make in
            #if !RTCUBE_OVERSEAS
            make.top.equalTo(rtcExperienceRoomBtn.snp.bottom).offset(12)
            #else
            make.top.equalTo(containerView.snp.bottom).offset(12)
            #endif
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(52)
        }
    }
    
    func bindInteraction() {
        userNameBtn.addTarget(self, action: #selector(userIdBtnClick(btn:)), for: .touchUpInside)
        backBtn.addTarget(self, action: #selector(goBack(sender:)), for: .touchUpInside)
        logoutBtn.addTarget(self, action: #selector(logout(sender:)), for: .touchUpInside)
        
        tableView.register(MineTableViewCell.self, forCellReuseIdentifier: "MineTableViewCell")
        tableView.delegate = self
        tableView.dataSource = self
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(headBtnClick))
        headImageView.addGestureRecognizer(tap)
        headImageView.isUserInteractionEnabled = true
        
        #if !RTCUBE_OVERSEAS
        rtcExperienceRoomBtn.onClicked = { [weak self] in
            self?.delegate?.jumpExperienceRoom()
        }
        #endif
        
        updateProfile()
    }
    
    // MARK: - Profile Updates
    
    func updateProfile() {
        DispatchQueue.main.async {
            self.updateHeadImage()
            self.updateName()
            self.updateUserId()
        }
    }
    
    func updateHeadImage() {
        if let url = URL(string: TUILogin.getFaceUrl() ?? "") {
            headImageView.kf.setImage(with: .network(url), placeholder: UIImage(named: "room_default_avatar"))
        } else {
            headImageView.image = UIImage(named: "default_avatar")
        }
    }
    
    func updateUserId() {
        userIdLabel.text = "ID:\(TUILogin.getUserID() ?? "")"
    }
    
    func updateName() {
        if let nickName = TUILogin.getNickName() {
            userNameBtn.setTitle(nickName, for: .normal)
            userNameBtn.sizeToFit()
            let totalWidth = userNameBtn.frame.width
            guard let imageView = userNameBtn.imageView else { return }
            let imageWidth = imageView.frame.width
            let titleWidth = totalWidth - imageWidth
            let spacing = CGFloat(4)
            let maxBtnWidth = ScreenWidth - 80
            let targetBtnWidth = totalWidth + spacing
            userNameBtn.titleEdgeInsets = UIEdgeInsets(top: 0, left: -imageWidth - spacing * 0.5, bottom: 0, right: imageWidth + spacing * 0.5)
            userNameBtn.imageEdgeInsets = UIEdgeInsets(top: 0, left: titleWidth + spacing * 0.5, bottom: 0, right: -titleWidth - spacing * 0.5)
            userNameBtn.snp.remakeConstraints { make in
                make.top.equalTo(headImageView.snp.bottom).offset(12)
                make.centerX.equalToSuperview()
                make.width.equalTo((targetBtnWidth > maxBtnWidth) ? maxBtnWidth : targetBtnWidth)
            }
        }
    }
    
    // MARK: - Hit Test
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let superview = headImageView.superview else {
            return super.hitTest(point, with: event)
        }
        let rect = superview.convert(headImageView.frame, to: self)
        if rect.contains(point) {
            return headImageView
        }
        return super.hitTest(point, with: event)
    }
    
    // MARK: - Actions
    
    @objc func userIdBtnClick(btn: UIButton) {
        delegate?.jumpProfileController()
    }
    
    @objc func headBtnClick() {
        delegate?.jumpProfileController()
    }
    
    @objc private func goBack(sender: UIButton) {
        delegate?.goBack()
    }
    
    @objc private func logout(sender: UIButton) {
        delegate?.logout()
    }
}

// MARK: - UITableViewDataSource

extension MineRootView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.tableDataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MineTableViewCell", for: indexPath)
        if let scell = cell as? MineTableViewCell {
            let model = viewModel.tableDataSource[indexPath.row]
            scell.model = model
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 58
    }
}

// MARK: - UITableViewDelegate

extension MineRootView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = viewModel.tableDataSource[indexPath.row]
        switch model.type {
        case .about:
            let vc = MineAboutViewController()
            vc.hidesBottomBarWhenPushed = true
            delegate?.navigationController?.pushViewController(vc, animated: true)
            
        case .privacy:
            PrivacyEntry.pushPrivacyPage(.privacyCenter, from: delegate)
            
        case .disclaimer:
            let alert = UIAlertController(
                title: MineLocalize("Demo.TRTC.Portal.disclaimerdesc"),
                message: "",
                preferredStyle: .alert
            )
            let action = UIAlertAction(title: MineLocalize("Demo.TRTC.Portal.confirm"), style: .default, handler: nil)
            alert.addAction(action)
            delegate?.present(alert, animated: true, completion: nil)
            
        case .icp:
            let openUrl = "https://beian.miit.gov.cn/#/home"
            TUITool.openLink(with: URL(string: openUrl))
        }
    }
}

// MARK: - MineTableViewCellModel

class MineTableViewCellModel: NSObject {
    let title: String
    let image: UIImage?
    let type: MineListType
    init(title: String, image: UIImage?, type: MineListType) {
        self.title = title
        self.image = image
        self.type = type
        super.init()
    }
}

// MARK: - MineTableViewCell

class MineTableViewCell: UITableViewCell {
    lazy var titleImageView: UIImageView = {
        let imageV = UIImageView(frame: .zero)
        return imageV
    }()
    
    lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Bold14
        label.textColor = ThemeStore.shared.colorTokens.textColorPrimary
        return label
    }()
    
    lazy var detailLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = ThemeStore.shared.typographyTokens.Regular12
        label.isHidden = true
        label.textColor = ThemeStore.shared.colorTokens.textColorSecondary
        label.textAlignment = .left
        return label
    }()
    
    lazy var detailImageView: UIImageView = {
        let imageV = UIImageView(image: UIImage(named: "main_mine_detail"))
        return imageV
    }()
    
    var model: MineTableViewCellModel? {
        didSet {
            guard let model = model else { return }
            titleImageView.image = model.image
            titleLabel.text = model.title
            if model.type == .icp {
                detailLabel.isHidden = false
                detailLabel.text = MineLocalize("Demo.TRTC.Portal.Mine.ICPDetailNumber")
            }
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
    }
    
    func constructViewHierarchy() {
        contentView.addSubview(titleImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailImageView)
        contentView.addSubview(detailLabel)
    }
    
    func activateConstraints() {
        titleImageView.snp.makeConstraints { make in
            make.centerX.equalTo(contentView.snp.leading).offset(36)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        detailImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(titleImageView)
            make.width.height.equalTo(18)
        }
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleImageView)
            make.leading.equalTo(titleImageView.snp.centerX).offset(28)
            make.trailing.lessThanOrEqualTo(detailImageView.snp.leading).offset(-10)
        }
        detailLabel.snp.makeConstraints { make in
            make.right.equalTo(detailImageView.snp.left).offset(-4)
            make.centerY.equalTo(titleImageView)
        }
    }
}

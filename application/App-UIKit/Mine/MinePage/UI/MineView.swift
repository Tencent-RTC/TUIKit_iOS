//
//  MineView.swift
//  App-UIKit
//
//  Created by yukiwwwang on 2025/8/8.
//

import Foundation
import Kingfisher
import UIKit
import TUICore
import AtomicXCore
import RTCCommon

protocol MineViewDelegate: NSObjectProtocol {
    func didTapBackOnMine()
    func didTapSettingsOnMine()
    func didTapLogOnMine()
    func didRequestLogout()
}

class MineView: UIView {
        
    let viewModel: MineViewModel
    weak var delegate: MineViewController?
    
    init(viewModel: MineViewModel, frame: CGRect = .zero) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    private let backBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setBackgroundImage(UIImage(named: "mine_goback"), for: .normal)
        btn.sizeToFit()
        return btn
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "PingFangSC-Semibold", size: 16)
        label.text = ("Personal Center").localized
        label.textAlignment = .center
        label.textColor = .black
        return label
    }()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let bgImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "mine_bg_icon")
        return imageView
    }()
    
    private let headImageDiameter: CGFloat = 72
    private lazy var headImageView: UIImageView = {
        let imageV = UIImageView(frame: .zero)
        imageV.contentMode = .scaleAspectFill
        imageV.layer.cornerRadius = headImageDiameter / 2
        imageV.clipsToBounds = true
        return imageV
    }()
    
    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.text = "USERID"
        label.textColor = UIColor("262B32")
        label.font = UIFont(name: "PingFangSC-Semibold", size: 18)
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    
    private let userIdLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont(name: "PingFangSC-Regular", size: 12)
        label.textColor = UIColor("626E84")
        return label
    }()
    
    private let containerView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .white
        return view
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 48, right: 0)
        return tableView
    }()
    

    private let logoutBtn: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle(("Log out").localized, for: .normal)
        btn.setTitleColor(UIColor("F33A50"), for: .normal)
        btn.titleLabel?.font = UIFont(name: "PingFangSC-Semibold", size: 16)
        btn.backgroundColor = UIColor.white
        btn.sizeToFit()
        return btn
    }()
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        containerView.roundedRect(rect: containerView.bounds, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 10, height: 10))
        logoutBtn.roundedRect(rect: logoutBtn.bounds, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 10, height: 10))
    }
    
    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        backgroundColor = UIColor("EBEDF5")
        isViewReady = true
        constructViewHierarchy()
        activateConstraints()
        bindInteraction()
        updateProfile()
    }
    
    private func constructViewHierarchy() {
        addSubview(bgImageView)
        addSubview(backBtn)
        addSubview(titleLabel)
        addSubview(headImageView)
        addSubview(userNameLabel)
        addSubview(userIdLabel)
        addSubview(containerView)
        containerView.addSubview(tableView)
        addSubview(logoutBtn)
    }
    
    private func activateConstraints() {
        bgImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.equalTo(screenWidth)
            make.height.equalTo(screenWidth * (112.0 / 375.0) + navigationFullHeight())
        }

        backBtn.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.leading.equalToSuperview().offset(20.scale375Width())
            make.width.height.equalTo(24.scale375Width())
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(statusBarHeight())
            make.centerX.equalToSuperview()
            make.width.equalTo(screenWidth/2.0)
            make.height.equalTo(44.scale375Height())
        }

        headImageView.snp.makeConstraints { make in
            make.bottom.equalTo(bgImageView)
            make.centerX.equalTo(bgImageView)
            make.width.height.equalTo(headImageDiameter)
        }

        userNameLabel.snp.makeConstraints { make in
            make.top.equalTo(headImageView.snp.bottom).offset(12.scale375Height())
            make.leading.equalToSuperview().offset(20.scale375Width())
            make.trailing.equalToSuperview().offset(-20.scale375Width())
            make.centerX.equalToSuperview()
        }

        userIdLabel.snp.makeConstraints { make in
            make.top.equalTo(userNameLabel.snp.bottom).offset(2.scale375Height())
            make.centerX.equalToSuperview()
        }

        containerView.snp.makeConstraints { make in
            make.top.equalTo(userIdLabel.snp.bottom).offset(20.scale375Height())
            make.leading.equalToSuperview().offset(20.scale375Width())
            make.trailing.equalToSuperview().offset(-20.scale375Width())
            make.height.equalTo(60.scale375Height() * CGFloat(viewModel.tableDataSource.count) + 6.scale375Height())
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(containerView.snp.top).offset(8.scale375Height())
            make.leading.trailing.equalTo(containerView)
            make.bottom.equalTo(containerView.snp.bottom).offset(-8.scale375Height())
        }

        logoutBtn.snp.makeConstraints { make in
            make.top.equalTo(containerView.snp.bottom).offset(12.scale375Height())
            make.leading.equalToSuperview().offset(20.scale375Width())
            make.trailing.equalToSuperview().offset(-20.scale375Width())
            make.height.equalTo(52.scale375Height())
        }
    }
    
    private func bindInteraction() {
        backBtn.addTarget(self, action: #selector(goBack(sender:)), for: .touchUpInside)
        logoutBtn.addTarget(self, action: #selector(logout(sender:)), for: .touchUpInside)
        tableView.register(MineTableViewCell.self, forCellReuseIdentifier: "MineTableViewCell")
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func updateProfile() {
        DispatchQueue.main.async {
            self.updateHeadImage()
            self.updateName()
            self.updateUserId()
        }
    }
    
    private func updateHeadImage() {
        if let url = URL(string: LoginStore.shared.state.value.loginUserInfo?.avatarURL ?? "") {
            headImageView.kf.setImage(with: .network(url), placeholder: UIImage(named: "default_avatar"))
        } else {
            headImageView.image = UIImage(named: "default_avatar")
        }
    }
    
    private func updateUserId() {
        if let userID = LoginStore.shared.state.value.loginUserInfo?.userID {
            userIdLabel.text = "ID:\(String(describing: userID))"
        }
    }
    
    private func updateName() {
        if let nickName = LoginStore.shared.state.value.loginUserInfo?.nickname {
            userNameLabel.text = nickName
            userNameLabel.snp.makeConstraints { make in
                make.top.equalTo(headImageView.snp.bottom).offset(12.scale375Height())
                make.centerX.equalToSuperview()
                make.width.lessThanOrEqualTo(screenWidth - 80.scale375Width())
            }
        }
    }
    
    @objc private func goBack(sender: UIButton) {
        delegate?.didTapBackOnMine()
    }
    
    @objc private func logout(sender: UIButton) {
        delegate?.didRequestLogout()
    }
}

extension MineView : UITableViewDataSource {
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

extension MineView : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = viewModel.tableDataSource[indexPath.row]
        switch model.type {
        case .settings:
            delegate?.didTapSettingsOnMine()
        case .log:
            delegate?.didTapLogOnMine()
        }
    }
}


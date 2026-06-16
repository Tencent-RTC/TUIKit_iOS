//
//  CallingSelectUserTableViewCell.swift
//  main
//
//  通话模块 - 搜索结果用户 Cell（头像 + 名称 + 呼叫/添加/删除按钮）
//

import UIKit
import Login

public enum CallingSelectUserButtonType {
    case call
    case add
    case delete
}

public class CallingSelectUserTableViewCell: UITableViewCell {
    private var isViewReady = false
    private var buttonAction: (() -> Void)?

    lazy var userImageView: UIImageView = {
        let img = UIImageView()
        return img
    }()

    lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.black
        label.backgroundColor = UIColor.clear
        return label
    }()

    let rightButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor("006EFF")
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 15 // NOTE: 不在 BorderRadiusToken 体系中，保留原值
        return button
    }()

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else { return }
        isViewReady = true
        contentView.addSubview(userImageView)
        userImageView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.width.height.equalTo(50)
            make.centerY.equalTo(self)
        }

        contentView.addSubview(nameLabel)
        nameLabel.snp.remakeConstraints { make in
            make.leading.equalTo(userImageView.snp.trailing).offset(12)
            make.trailing.top.bottom.equalTo(self)
        }

        contentView.addSubview(rightButton)
        rightButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
            make.height.equalTo(30)
            make.right.equalToSuperview().offset(-20)
        }

        rightButton.addTarget(self, action: #selector(callAction(_:)), for: .touchUpInside)
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        self.buttonAction = nil
    }

    public func config(model: UserModel, type: CallingSelectUserButtonType, selected: Bool = false, action: (() -> Void)? = nil) {
        backgroundColor = UIColor.clear
        var btnName = ""

        if let imageURL = URL(string: model.avatar) {
            userImageView.kf.setImage(with: .network(imageURL))
        }

        userImageView.layer.masksToBounds = true
        userImageView.layer.cornerRadius = 25 // NOTE: 不在 BorderRadiusToken 体系中，保留原值
        nameLabel.text = model.name != "" ? model.name : model.userId
        buttonAction = action

        switch type {
        case .call:
            btnName = CallingLocalize("assembly_call_btn_streaming_call")
        case .add:
            btnName = CallingLocalize("assembly_call_btn_add")
        case .delete:
            btnName = CallingLocalize("assembly_call_btn_delete")
        }
        rightButton.setTitle(btnName, for: .normal)
    }

    @objc
    func callAction(_ sender: UIButton) {
        if let action = self.buttonAction {
            action()
        }
    }
}

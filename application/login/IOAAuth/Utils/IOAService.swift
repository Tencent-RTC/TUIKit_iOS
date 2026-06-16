//
//  IOAService.swift
//  login
//
//  iOA SDK 封装
//  封装 ITLogin.sharedInstance().showView() / dimissLoginView()
//  保留旧版中通过 NSStringFromClass 查找 ITLogin 子视图并 bringToFront 的逻辑
//

import UIKit
import ITLogin

class IOAService {
    
    /// 展示 iOA 登录视图
    /// - Parameter parentView: 父视图，用于查找 ITLogin 子视图并前置
    func showLoginView(in parentView: UIView?) {
        ITLogin.sharedInstance().showView()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let parentView = parentView else { return }
            
            // 在 window 层查找 ITLogin 子视图
            if let window = parentView.window {
                for subview in window.subviews {
                    if NSStringFromClass(type(of: subview)).contains("ITLogin") {
                        window.bringSubviewToFront(subview)
                        self.addBackButton(to: subview)
                        break
                    }
                }
            }
            
            // 在当前视图层查找 ITLogin 子视图
            for subview in parentView.subviews {
                if NSStringFromClass(type(of: subview)).contains("ITLogin") {
                    parentView.bringSubviewToFront(subview)
                    self.addBackButton(to: subview)
                    break
                }
            }
        }
    }
    
    /// 关闭 iOA 登录视图
    func dismissLoginView() {
        ITLogin.sharedInstance().dimissLoginView()
    }
    
    // MARK: - Private
    
    private static let backButtonTag = 6343
    
    private var onBackButtonTapped: (() -> Void)?
    
    /// 设置返回按钮回调
    func setOnBackButtonTapped(_ handler: @escaping () -> Void) {
        onBackButtonTapped = handler
    }
    
    private func addBackButton(to ioaView: UIView) {
        if let existingButton = ioaView.viewWithTag(IOAService.backButtonTag) as? UIButton {
            // ITLogin 视图可能被 SDK 复用，按钮已存在但 target 指向旧实例
            // 必须重新绑定 target 到当前 IOAService 实例
            existingButton.removeTarget(nil, action: nil, for: .touchUpInside)
            existingButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
            return
        }
        
        let closeButton = UIButton(type: .custom)
        closeButton.tag = IOAService.backButtonTag
        closeButton.setImage(UIImage.loginImage(named: "main_mine_about_back"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        ioaView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(ioaView.safeAreaLayoutGuide.snp.top).offset(10)
            make.left.equalTo(ioaView).offset(10)
            make.width.height.equalTo(40)
        }
    }
    
    @objc private func closeButtonTapped() {
        dismissLoginView()
        onBackButtonTapped?()
    }
}

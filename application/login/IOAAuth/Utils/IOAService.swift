//
//  IOAService.swift
//  login
//

import UIKit
import ITLogin

class IOAService {
    
    func showLoginView(in parentView: UIView?) {
        ITLogin.sharedInstance().showView()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let parentView = parentView else { return }
            
            if let window = parentView.window {
                for subview in window.subviews {
                    if NSStringFromClass(type(of: subview)).contains("ITLogin") {
                        window.bringSubviewToFront(subview)
                        self.addBackButton(to: subview)
                        break
                    }
                }
            }
            
            for subview in parentView.subviews {
                if NSStringFromClass(type(of: subview)).contains("ITLogin") {
                    parentView.bringSubviewToFront(subview)
                    self.addBackButton(to: subview)
                    break
                }
            }
        }
    }
    
    func dismissLoginView() {
        ITLogin.sharedInstance().dimissLoginView()
    }
    
    // MARK: - Private
    
    private static let backButtonTag = 6343
    
    private var onBackButtonTapped: (() -> Void)?
    
    func setOnBackButtonTapped(_ handler: @escaping () -> Void) {
        onBackButtonTapped = handler
    }
    
    private func addBackButton(to ioaView: UIView) {
        if ioaView.viewWithTag(IOAService.backButtonTag) != nil {
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

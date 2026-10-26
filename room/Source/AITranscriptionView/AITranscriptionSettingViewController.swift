//
//  AITranscriptionSettingViewController.swift
//  TUIRoomKit
//
//  Created on 2026/3/11.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit

public class AITranscriptionSettingViewController: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var settingView: AITranscriptionSettingView = {
        let settingView = AITranscriptionSettingView()
        return settingView
    }()
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        setupBindings()
    }
    
    /// Bind the repository. Must be called before pushing this view controller.
    public func bindRepository(_ repository: AITranscriberRepository) {
        settingView.bindRepository(repository)
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        view.addSubview(settingView)
    }
    
    private func setupConstraints() {
        settingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupBindings() {
        settingView.delegate = self
    }
}

extension AITranscriptionSettingViewController: AITranscriptionSettingViewDelegate {
    public func settingViewDidTapBack(_ settingView: AITranscriptionSettingView) {
        navigationController?.popViewController(animated: true)
    }
}

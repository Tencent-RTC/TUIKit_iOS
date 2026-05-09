//
//  AIMinutesViewController.swift
//  TUIRoomKit
//
//  Created on 2026/3/10.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import SnapKit

public class AIMinutesViewController: UIViewController {
    
    // MARK: - Properties
    
    private let config: AIMinutesConfig = .default
    
    // MARK: - UI Components
    
    private lazy var minutesView: AIMinutesView = {
        let minutesView = AIMinutesView()
        minutesView.configure(with: config)
        return minutesView
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
        minutesView.bindRepository(repository)
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        view.addSubview(minutesView)
    }
    
    private func setupConstraints() {
        minutesView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupBindings() {
        minutesView.delegate = self
    }
}

extension AIMinutesViewController: AIMinutesViewDelegate {
    public func minutesViewDidTapBack(_ minutesView: AIMinutesView) {
        navigationController?.popViewController(animated: true)
    }
}

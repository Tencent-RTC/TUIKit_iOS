//
//  FloatWindowViewController.swift
//  Pods
//
//  Created by vincepzhang on 2025/2/25.
//

import UIKit
import AtomicXCore
import AtomicX
import SnapKit

class FloatWindowViewController: UIViewController {
    
    var tapGestureAction: ((UITapGestureRecognizer) -> Void)?
    var panGestureAction: ((UIPanGestureRecognizer) -> Void)?

    private lazy var coreView: CallCoreView = {
        let view = CallCoreView()
        return view
    }()

    private let gestureView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.addSubview(coreView)
        view.addSubview(gestureView)
        
        coreView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        gestureView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        coreView.setLayoutTemplate(.pip)
        
        gestureView.backgroundColor = UIColor.clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        gestureView.addGestureRecognizer(tap)
        gestureView.addGestureRecognizer(pan)
    }
    
    // MARK: - Gesture Action
    @objc private func handleTapGesture(_ tapGesture: UITapGestureRecognizer) {
        tapGestureAction?(tapGesture)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: EVENT_TAP_FLOATWINDOW), object: nil)
    }
    
    @objc private func handlePanGesture(_ panGesture: UIPanGestureRecognizer) {
        panGestureAction?(panGesture)
    }
}

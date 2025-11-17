//
//  VRToastService.swift
//  TUILiveKit
//
//  Created by CY zhao on 2025/9/30.
//

import Foundation
import Combine

protocol VRToastService {
    func showToast(_ message: String)
    func subscribeToast(_ callback: @escaping (String) -> Void)
}


class VRToastServiceImpl: VRToastService {
    private let toastSubject = PassthroughSubject<String, Never>()
    private var cancellableSet: Set<AnyCancellable> = []
    
    func showToast(_ message: String) {
        toastSubject.send(message)
    }
    
    func subscribeToast(_ callback: @escaping (String) -> Void) {
        toastSubject
            .receive(on: RunLoop.main)
            .sink { message in
                callback(message)
            }
            .store(in: &cancellableSet)
    }
}


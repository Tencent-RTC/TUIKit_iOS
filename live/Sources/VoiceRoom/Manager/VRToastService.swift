//
//  VRToastService.swift
//  TUILiveKit
//
//  Created by CY zhao on 2025/9/30.
//

import Foundation
import Combine
import AtomicX

protocol VRToastService {
    func showToast(_ message: String, toastStyle: ToastStyle)
    func subscribeToast(_ callback: @escaping (String, ToastStyle) -> Void)
}


class VRToastServiceImpl: VRToastService {
    private let toastSubject = PassthroughSubject<(String, ToastStyle), Never>()
    private var cancellableSet: Set<AnyCancellable> = []
    
    func showToast(_ message: String, toastStyle: ToastStyle) {
        toastSubject.send((message, toastStyle))
    }
    
    func subscribeToast(_ callback: @escaping (String, ToastStyle) -> Void) {
        toastSubject
            .receive(on: RunLoop.main)
            .sink { message, style in
                callback(message, style)
            }
            .store(in: &cancellableSet)
    }
}


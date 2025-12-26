//
//  ViewState.swift
//  TUICallKit_swift
//
//  Created by vincepzhang on 2025/2/6.
//

import RTCCommon

class ViewState: NSObject {
    let router: Observable<ViewRouter> = Observable(.none)
    let isScreenCleaned: Observable<Bool> = Observable(false)
    
    enum ViewRouter {
        case none
        case banner
        case fullView
        case floatView
    }
    
    func reset() {
        router.value = .none
        isScreenCleaned.value = false
    }
}
 

//
//  LiveListViewDefine.swift
//  TUILiveKit
//
//  Created by jeremiawang on 2025/4/29.
//

import AtomicXCore
 
public enum LiveListViewStyle {
    case singleColumn
    case doubleColumn
}

public protocol LiveListViewAdapter: AnyObject {
    func createLiveInfoView(info: LiveInfo) -> UIView
    func updateLiveInfoView(view: UIView, info: LiveInfo) -> Void
}

public protocol LiveListDataSource: AnyObject {
    typealias LiveListBlock = (String, [LiveInfo]) -> Void
    typealias LiveListErrorBlock = (ErrorInfo) -> Void
    func fetchLiveList(cursor: String, onSuccess: @escaping LiveListBlock, onError: @escaping LiveListErrorBlock)
}

public protocol OnItemClickDelegate: AnyObject {
    func onItemClick(liveInfo: LiveInfo, frame: CGRect)
}

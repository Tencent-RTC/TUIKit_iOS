//
//  TUIGiftAnimationManager.swift
//  TUILiveKit
//
//  Created by krabyu on 2024/1/2.
//

import Foundation
import AtomicX

typealias TUIDequeueClosure = (TUIGiftData) -> Void

class TUIGiftAnimationManager {
    private var waitQueue: [TUIGiftData] = []
    private let maxQueueLength = 20
    
    var dequeueClosure: TUIDequeueClosure?
    let maxChannels: Int
    var currentPlayingCount: Int = 0

    init(simulcastCount: Int = 3) {
        self.maxChannels = simulcastCount
    }

    func enqueue(giftData: TUIGiftData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 1. 快速通道：如果有空闲跑道，直接播放
            if self.currentPlayingCount < self.maxChannels {
                self.playDirectly(giftData)
                return
            }
            
            // 2. 满员处理：加入等待队列（带聚合逻辑）
            self.addToQueueWithAggregation(giftData)
        }
    }
    
    func finishPlay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentPlayingCount = max(0, self.currentPlayingCount - 1)
            
            if !self.waitQueue.isEmpty {
                let nextGift = self.waitQueue.removeFirst()
                self.playDirectly(nextGift)
            }
        }
    }

    func clearData() {
        DispatchQueue.main.async { [weak self] in
            self?.waitQueue.removeAll()
            self?.currentPlayingCount = 0
        }
    }
    
    // MARK: - Private Logic
    
    private func playDirectly(_ giftData: TUIGiftData) {
        currentPlayingCount += 1
        dequeueClosure?(giftData)
    }
    
    private func addToQueueWithAggregation(_ giftData: TUIGiftData) {
        // A. 聚合：检查队列里是否有同一种礼物
        if let index = waitQueue.firstIndex(where: { $0.comboKey == giftData.comboKey }) {
            // 直接修改队列中的对象，累加数量
            waitQueue[index].giftCount += giftData.giftCount
            
            // 可选：聚合后是否要把这个任务提到前面？
            // 如果想让正在连击的人不被饿死，可以不动位置；
            // 如果想优先展示活跃的，可以 moveToFront。这里暂保持原位。
        } else {
            // B. 新任务入队
            // 插队逻辑：如果是自己发的，插到队头
            if giftData.sender.isSelf {
                waitQueue.insert(giftData, at: 0)
            } else {
                waitQueue.append(giftData)
            }
            
            // C. 溢出保护：如果队列太长，丢弃最旧的非自己礼物
            if waitQueue.count > maxQueueLength {
                // 优先丢弃别人的，保留自己的
                if let removeIndex = waitQueue.lastIndex(where: { !$0.sender.isSelf }) {
                    waitQueue.remove(at: removeIndex)
                } else {
                    waitQueue.removeFirst() // 实在不行只能丢第一个
                }
            }
        }
    }
}

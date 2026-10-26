//
//  SingleStreamManager.swift
//  TUIRoomKit
//
//  Created by adamsfliu on 2026/8/17.
//  Copyright © 2026 Tencent. All rights reserved.
//

import UIKit
import AtomicXCore

// MARK: - SingleStreamLayoutMode
enum SingleStreamLayoutMode: Equatable {
    case remoteFullScreenWithLocal
    case screenShareWithSpeaker
    case hidden
}

// MARK: - SingleStreamManager
class SingleStreamManager {

    // MARK: - Configuration
    private struct Config {
        static let speakerSwitchInterval: TimeInterval = 5
        static let speakerVolumeMinLimit: Int = 10
        static let portraitWidth: CGFloat = 100
        static let portraitHeight: CGFloat = 180
        static let landscapeWidth: CGFloat = 180
        static let landscapeHeight: CGFloat = 100
        static let audioOnlySize: CGFloat = 100
        static let margin: CGFloat = 5
        static let topMargin: CGFloat = 5
    }

    // MARK: - Properties
    private let roomID: String
    private weak var hostView: UIView?
    let singleStreamView: RoomSingleStreamView

    var onRenderReleased: ((String) -> Void)?

    private(set) var layoutMode: SingleStreamLayoutMode = .hidden

    private var currentSpeakerUserID: String?

    private var lastSpeakerSwitchTime: TimeInterval = 0
 
    private var isShowingFallback: Bool = false
    
    private var pendingRenderActivation: DispatchWorkItem?
    
    private var currentScrollOffsetX: CGFloat = 0
    
    private var currentPageWidth: CGFloat = 0
    
    private var isOnScreenSharePage: Bool {
        guard currentPageWidth > 0 else { return true }
        return currentScrollOffsetX < currentPageWidth / 2
    }

    // MARK: - Initialization
    init(roomID: String, hostView: UIView) {
        self.roomID = roomID
        self.hostView = hostView
        self.singleStreamView = RoomSingleStreamView(roomID: roomID, isDraggable: true)
        self.singleStreamView.isHidden = true
        self.singleStreamView.onVideoStatusChanged = { [weak self] in
            self?.updateFrame()
        }
    }

    // MARK: - Public API
    func updateLayoutMode(participants: [RoomParticipant], hasScreenShare: Bool, speakingUsers: [String: Int]) {
        let count = participants.count
        let mode: SingleStreamLayoutMode
        if hasScreenShare {
            mode = count >= 2 ? .screenShareWithSpeaker : .hidden
        } else if count == 2 {
            mode = .remoteFullScreenWithLocal
        } else {
            mode = .hidden
        }

        let modeChanged = mode != layoutMode
        layoutMode = mode
        if modeChanged {
            currentSpeakerUserID = nil
            lastSpeakerSwitchTime = 0
            isShowingFallback = false
        }
        applyMode(participants: participants, speakingUsers: speakingUsers)
    }

    private func applyMode(participants: [RoomParticipant], speakingUsers: [String: Int]) {
        switch layoutMode {
        case .remoteFullScreenWithLocal:
            let localID = localUserID()
            let localParticipant = participants.first { $0.userID == localID }
            guard let local = localParticipant else {
                hideAndClearParticipant()
                return
            }
            
            singleStreamView.isHidden = false
            updateFrame()
            if currentSpeakerUserID != local.userID {
                currentSpeakerUserID = local.userID
                singleStreamView.updateParticipant(local)
            }
        case .screenShareWithSpeaker:
            guard isOnScreenSharePage else { return }
            trySwitchSpeaker(participants: participants, speakingUsers: speakingUsers)
        case .hidden:
            hideAndClearParticipant()
        }
        updateFrame()
        singleStreamView.ensureRenderActive()
    }

    func updateSpeakingStatus(participants: [RoomParticipant], speakingUsers: [String: Int], collectionViewOffsetX: CGFloat) {
        currentScrollOffsetX = collectionViewOffsetX
        if layoutMode == .screenShareWithSpeaker {
            trySwitchSpeaker(participants: participants, speakingUsers: speakingUsers)
        }
        if !singleStreamView.isHidden, let participant = singleStreamView.participant {
            let volume = speakingUsers[participant.userID] ?? 0
            let hasAudio = participant.microphoneStatus == .on
            singleStreamView.updateVolume(hasAudio: hasAudio, volume: volume)
        }
    }

    func handleScroll(offsetX: CGFloat, pageWidth: CGFloat) {
        currentScrollOffsetX = offsetX
        currentPageWidth = pageWidth
        guard layoutMode == .screenShareWithSpeaker else { return }
        if isOnScreenSharePage {
            let wasHidden = singleStreamView.isHidden
            singleStreamView.isHidden = false
            if wasHidden {
                updateFrame()
                scheduleRenderActivation()
            }
        } else {
            cancelPendingRenderActivation()
            releaseRenderAndNotify()
            singleStreamView.isHidden = true
        }
    }

    private func releaseRenderAndNotify() {
        guard !singleStreamView.isHidden else { return }
        let releasedUserID = singleStreamView.participant?.userID
        singleStreamView.releaseRender()
        guard let releasedUserID = releasedUserID else { return }
        onRenderReleased?(releasedUserID)
    }

    private func hideAndClearParticipant() {
        let releasedUserID = singleStreamView.participant?.userID
        currentSpeakerUserID = nil
        isShowingFallback = false
        singleStreamView.updateParticipant(nil)
        singleStreamView.isHidden = true
        guard let releasedUserID = releasedUserID else { return }
        onRenderReleased?(releasedUserID)
    }

    func handleScrollEnd(offsetX: CGFloat, pageWidth: CGFloat) {
        currentScrollOffsetX = offsetX
        currentPageWidth = pageWidth
        guard layoutMode == .screenShareWithSpeaker else { return }
        guard isOnScreenSharePage else { return }
        cancelPendingRenderActivation()
        singleStreamView.isHidden = false
        updateFrame()
        singleStreamView.ensureRenderActive()
    }

    func restoreRenderIfShowing(userID: String) {
        guard layoutMode == .screenShareWithSpeaker else { return }
        guard !singleStreamView.isHidden else { return }
        guard singleStreamView.participant?.userID == userID else { return }
        scheduleRenderActivation()
    }

    private func scheduleRenderActivation() {
        cancelPendingRenderActivation()
        let workItem = DispatchWorkItem { [weak self] in
            self?.singleStreamView.ensureRenderActive()
        }
        pendingRenderActivation = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func cancelPendingRenderActivation() {
        pendingRenderActivation?.cancel()
        pendingRenderActivation = nil
    }

    func updateFrame() {
        guard !singleStreamView.isHidden, let hostView = hostView else { return }
        let bounds = hostView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        let isPortrait = bounds.height > bounds.width
        var height = isPortrait ? Config.portraitHeight : Config.landscapeHeight
        var width = isPortrait ? Config.portraitWidth : Config.landscapeWidth
        if let participant = singleStreamView.participant,
           !participant.hasCameraVideoForSingleStream {
            height = Config.audioOnlySize
            width = Config.audioOnlySize
        }
        if singleStreamView.originalX == 0 {
            singleStreamView.setupFrame(CGRect(
                x: bounds.size.width - width - Config.margin,
                y: Config.topMargin,
                width: width,
                height: height
            ))
            singleStreamView.ensureRenderActive()
        } else {
            singleStreamView.updateSize(size: CGSize(width: width, height: height))
        }
    }

    // MARK: - Private

    private func localUserID() -> String {
        LoginStore.shared.state.value.loginUserInfo?.userID ?? ""
    }

    private func detectSpeaker(participants: [RoomParticipant], speakingUsers: [String: Int]) -> RoomParticipant? {
        var maxVolume: Int = 0
        var loudest: RoomParticipant?
        for (userID, volume) in speakingUsers where volume > Config.speakerVolumeMinLimit {
            guard let participant = participants.first(where: { $0.userID == userID }) else { continue }
            guard participant.microphoneStatus == .on else { continue }
            if volume > maxVolume {
                maxVolume = volume
                loudest = participant
            }
        }
        return loudest
    }

    private func trySwitchSpeaker(participants: [RoomParticipant], speakingUsers: [String: Int]) {
        guard isOnScreenSharePage else { return }

        if let speaker = detectSpeaker(participants: participants, speakingUsers: speakingUsers) {
            switchToSpeaker(speaker, participants: participants)
            return
        }
        if currentSpeakerUserID == nil || !isCurrentSpeakerValid(in: participants) {
            showFallbackParticipant(participants: participants)
        }
    }

    private func switchToSpeaker(_ speaker: RoomParticipant, participants: [RoomParticipant]) {
        guard speaker.userID != currentSpeakerUserID else {
            isShowingFallback = false
            return
        }

        let canSwitchImmediately = isShowingFallback
            || currentSpeakerUserID == nil
            || !isCurrentSpeakerValid(in: participants)
        if !canSwitchImmediately {
            let now = Date().timeIntervalSince1970
            guard now - lastSpeakerSwitchTime >= Config.speakerSwitchInterval else { return }
        }

        isShowingFallback = false
        lastSpeakerSwitchTime = Date().timeIntervalSince1970
        display(speaker)
    }

    private func showFallbackParticipant(participants: [RoomParticipant]) {
        let localID = localUserID()
        guard let local = participants.first(where: { $0.userID == localID }) else { return }
        isShowingFallback = true
        guard local.userID != currentSpeakerUserID else { return }
        display(local)
    }

    private func isCurrentSpeakerValid(in participants: [RoomParticipant]) -> Bool {
        guard let currentID = currentSpeakerUserID else { return false }
        return participants.contains { $0.userID == currentID }
    }

    private func display(_ participant: RoomParticipant) {
        currentSpeakerUserID = participant.userID
        singleStreamView.isHidden = false
        updateFrame()
        singleStreamView.updateParticipant(participant)
    }
}

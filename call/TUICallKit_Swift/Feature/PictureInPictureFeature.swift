//
//  PictureInPictureFeature.swift (Final Refactored Version)
//  TUICallKit_Swift
//
//  Created by noah on 2025/8/7.
//

import Foundation
import RTCRoomEngine
import SDWebImage
import ImSDK_Plus
import Combine
import AtomicXCore

enum PictureInPictureFillMode: Int, Codable {
    case fill = 0
    case fit = 1
}

struct PictureInPictureRegion: Codable {
    let userId: String
    let width: Double
    let height: Double
    let x: Double
    let y: Double
    let fillMode: PictureInPictureFillMode
    let streamType: String
    let backgroundColor: String
    let backgroundImage: String?
    
    init(userId: String, width: Double, height: Double, x: Double, y: Double, fillMode: PictureInPictureFillMode, streamType: String, backgroundColor: String, backgroundImage: String? = nil) {
        self.userId = userId
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        self.fillMode = fillMode
        self.streamType = streamType
        self.backgroundColor = backgroundColor
        self.backgroundImage = backgroundImage
    }
}

struct PictureInPictureCanvas: Codable {
    let width: Int
    let height: Int
    let backgroundColor: String
}

struct PictureInPictureParams: Codable {
    let enable: Bool
    let cameraBackgroundCapture: Bool?
    let canvas: PictureInPictureCanvas?
    var regions: [PictureInPictureRegion]?
    
    init(enable: Bool, cameraBackgroundCapture: Bool? = nil, canvas: PictureInPictureCanvas? = nil, regions: [PictureInPictureRegion]? = nil) {
        self.enable = enable
        self.cameraBackgroundCapture = cameraBackgroundCapture
        self.canvas = canvas
        self.regions = regions
    }
}

struct PictureInPictureRequest: Codable {
    let api: String
    var params: PictureInPictureParams
}

// MARK: - Configuration
private struct PictureInPictureConfiguration {
    static let backgroundColor = "#111111"
    static let canvasWidth = 720
    static let canvasHeight = 1280
    static let apiName = "configPictureInPicture"
    static let maxGridUsers = 9
}

class PictureInPictureFeature: NSObject {
    private var currentRequest: PictureInPictureRequest?
    private var cancellables = Set<AnyCancellable>()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init() {
        super.init()
        subscribeCallState()
        let params = PictureInPictureParams(enable: true, cameraBackgroundCapture: true)
        sendPictureInPictureRequest(params)
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    func updatePictureInPicture(allUsers: [CallParticipantInfo]) {
        var userList = allUsers
        let selfInfo = CallStore.shared.state.value.selfInfo
        
        if !userList.contains(where: { $0.id == selfInfo.id }) {
            userList.append(selfInfo)
        }
        
        guard !userList.isEmpty else { return }
        
        let regions = calculateLayout(for: userList)
        guard !regions.isEmpty else { return }
        
        let canvas = PictureInPictureCanvas(width: PictureInPictureConfiguration.canvasWidth,
                                            height: PictureInPictureConfiguration.canvasHeight,
                                            backgroundColor: PictureInPictureConfiguration.backgroundColor)
        let params = PictureInPictureParams(enable: true, cameraBackgroundCapture: true, canvas: canvas, regions: regions)
        
        sendPictureInPictureRequest(params)
        downloadAvatars(for: userList)
    }
    
    func closePictureInPicture() {
        let params = PictureInPictureParams(enable: false)
        sendPictureInPictureRequest(params)
    }
    
    private func downloadAvatars(for users: [CallParticipantInfo]) {
        let userIDs = users.map { $0.id }
        
        UserManager.getUserInfosFromIM(userIDs: userIDs) { userList in
            for user in userList {
                let avatarUrl = user.avatarURL
                guard !avatarUrl.isEmpty, let url = URL(string: avatarUrl) else { continue }
                
                SDWebImageDownloader.shared.downloadImage(with: url) { [weak self, user] image, _, _, finished in
                    guard let self = self else { return }
                    
                    if let image = image, finished {
                        let cacheKey = SDWebImageManager.shared.cacheKey(for: url)
                        SDImageCache.shared.store(image, forKey: cacheKey, toDisk: true) {
                            if let cachePath = SDImageCache.shared.cachePath(forKey: cacheKey) {
                                self.setBackgroundImage(forUserId: user.id, to: "file://" + cachePath)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func setBackgroundImage(forUserId userId: String, to backgroundImage: String) {
        guard var currentRequest = self.currentRequest,
              let regions = currentRequest.params.regions,
              currentRequest.params.enable else { return }
        
        let updatedRegions = regions.map { region -> PictureInPictureRegion in
            if region.userId == userId {
                return PictureInPictureRegion(
                    userId: region.userId,
                    width: region.width,
                    height: region.height,
                    x: region.x,
                    y: region.y,
                    fillMode: region.fillMode,
                    streamType: region.streamType,
                    backgroundColor: region.backgroundColor,
                    backgroundImage: backgroundImage
                )
            } else {
                return region
            }
        }
        
        if currentRequest.params.regions?.count != updatedRegions.count ||
           !zip(currentRequest.params.regions ?? [], updatedRegions).allSatisfy({ $0.backgroundImage == $1.backgroundImage }) {
            currentRequest.params.regions = updatedRegions
            sendPictureInPictureRequest(currentRequest.params)
        }
    }
    
    private func sendPictureInPictureRequest(_ params: PictureInPictureParams) {
        let request = PictureInPictureRequest(api: PictureInPictureConfiguration.apiName, params: params)
        self.currentRequest = request
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(request), let jsonString = String(data: data, encoding: .utf8) {
            TUICallEngine.createInstance().callExperimentalAPI(jsonObject: jsonString)
        }
    }
}

extension PictureInPictureFeature {
    private func calculateLayout(for users: [CallParticipantInfo]) -> [PictureInPictureRegion] {
        var regions: [PictureInPictureRegion] = []
        
        switch users.count {
        case 1:
            regions.append(createFullScreenRegion(for: users[0]))
        case 2:
            regions.append(contentsOf: createTwoPersonLayout(for: users))
        case 3:
            regions.append(contentsOf: createThreePersonLayout(for: users))
        case 4:
            regions.append(contentsOf: createFourPersonLayout(for: users))
        default:
            regions.append(contentsOf: createGridLayout(for: users))
        }
        
        return regions
    }
    
    private func createFullScreenRegion(for user: CallParticipantInfo) -> PictureInPictureRegion {
        return PictureInPictureRegion(
            userId: user.id,
            width: 1.0, height: 1.0, x: 0.0, y: 0.0,
            fillMode: .fill, streamType: "high", backgroundColor: PictureInPictureConfiguration.backgroundColor
        )
    }
    
    private func createTwoPersonLayout(for users: [CallParticipantInfo]) -> [PictureInPictureRegion] {
        let selfId = CallStore.shared.state.value.selfInfo.id
        let otherUsers = users.filter { $0.id != selfId }
        let selfUser = users.first { $0.id == selfId }
        
        var regions: [PictureInPictureRegion] = []
        
        for user in otherUsers {
            regions.append(PictureInPictureRegion(
                userId: user.id,
                width: 1.0, height: 1.0, x: 0.0, y: 0.0,
                fillMode: .fill, streamType: "high", backgroundColor: PictureInPictureConfiguration.backgroundColor
            ))
        }
        
        if let selfUser = selfUser {
            regions.append(PictureInPictureRegion(
                userId: selfUser.id,
                width: 1.0/3.0, height: 1.0/3.0, x: 0.65, y: 0.05,
                fillMode: .fill, streamType: "high", backgroundColor: PictureInPictureConfiguration.backgroundColor
            ))
        }
        
        return regions
    }
    
    private func createThreePersonLayout(for users: [CallParticipantInfo]) -> [PictureInPictureRegion] {
        var regions: [PictureInPictureRegion] = []
        
        for (index, user) in users.enumerated() {
            if index < 2 {
                let x = index == 0 ? 0.0 : 0.5
                regions.append(PictureInPictureRegion(
                    userId: user.id,
                    width: 0.5, height: 0.5, x: x, y: 0.0,
                    fillMode: .fill, streamType: "high", backgroundColor: PictureInPictureConfiguration.backgroundColor
                ))
            } else {
                regions.append(PictureInPictureRegion(
                    userId: user.id,
                    width: 0.5, height: 0.5, x: 0.25, y: 0.5,
                    fillMode: .fill, streamType: "high", backgroundColor: PictureInPictureConfiguration.backgroundColor
                ))
            }
        }
        
        return regions
    }
    
    private func createFourPersonLayout(for users: [CallParticipantInfo]) -> [PictureInPictureRegion] {
        var regions: [PictureInPictureRegion] = []
        
        for (index, user) in users.enumerated() {
            let row = index / 2
            let col = index % 2
            regions.append(PictureInPictureRegion(
                userId: user.id,
                width: 0.5, height: 0.5, x: Double(col) * 0.5, y: Double(row) * 0.5,
                fillMode: .fill, streamType: "high", backgroundColor: PictureInPictureConfiguration.backgroundColor
            ))
        }
        
        return regions
    }
    
    private func createGridLayout(for users: [CallParticipantInfo]) -> [PictureInPictureRegion] {
        var regions: [PictureInPictureRegion] = []
        
        for (index, user) in users.prefix(PictureInPictureConfiguration.maxGridUsers).enumerated() {
            let row = index / 3
            let col = index % 3
            regions.append(PictureInPictureRegion(
                userId: user.id,
                width: 1.0/3.0, height: 1.0/3.0, x: Double(col) * 1.0/3.0, y: Double(row) * 1.0/3.0,
                fillMode: .fill, streamType: "high", backgroundColor: PictureInPictureConfiguration.backgroundColor
            ))
        }
        
        return regions
    }
}

// MARK: Subscribe
extension PictureInPictureFeature {
    private func subscribeCallState() {
        CallStore.shared.state.subscribe(StatePublisherSelector { state -> [String] in
            return state.allParticipants.map { "\($0.id)_\($0.status)_\($0.isCameraOpened)" }
        })
        .removeDuplicates()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            guard let self = self else { return }
            self.handleParticipantsChanged()
        }
        .store(in: &cancellables)
        
        CallStore.shared.state.subscribe(StatePublisherSelector<CallState, CallParticipantStatus>(keyPath: \.selfInfo.status))
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                if status == .accept {
                    self.handleParticipantsChanged()
                } else if status == .none {
                    self.closePictureInPicture()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleParticipantsChanged() {
        let state = CallStore.shared.state.value
        let participants = state.allParticipants
        
        if participants.isEmpty {
            if let currentRequest = self.currentRequest, currentRequest.params.enable {
                closePictureInPicture()
            }
            return
        }
        
        let activeCall = state.activeCall
        if activeCall.mediaType == .video || participants.count > 2 || !activeCall.chatGroupId.isEmpty {
            updatePictureInPicture(allUsers: participants)
        }
    }
}

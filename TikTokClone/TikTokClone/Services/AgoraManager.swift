import Foundation
import AgoraRtcKit
import SwiftUI

class AgoraManager: NSObject, ObservableObject {
    static let shared = AgoraManager()
    
    @Published var isInStream: Bool = false
    @Published var error: String?
    @Published var remoteUsers: [UInt] = []
    
    private var agoraEngine: AgoraRtcEngineKit?
    private let appId = "100058b20ef3410997a741498f12e668"
    
    override private init() {
        super.init()
        initializeAgoraEngine()
    }
    
    private func initializeAgoraEngine() {
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        
        agoraEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
    }
    
    func joinChannel(token: String, channelName: String, as role: AgoraClientRole) {
        // Enable video module
        agoraEngine?.enableVideo()
        
        // Set up local video view
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.renderMode = .hidden
        agoraEngine?.setupLocalVideo(videoCanvas)
        
        // Set channel profile
        agoraEngine?.setChannelProfile(.liveBroadcasting)
        
        // Set client role
        agoraEngine?.setClientRole(role)
        
        // Join the channel
        agoraEngine?.joinChannel(
            byToken: token,
            channelId: channelName,
            info: nil,
            uid: 0,
            joinSuccess: { [weak self] (channel, uid, elapsed) in
                print("Successfully joined channel: \(channel)")
                self?.isInStream = true
            }
        )
    }
    
    func leaveChannel() {
        agoraEngine?.leaveChannel(nil)
        isInStream = false
        remoteUsers.removeAll()
    }
    
    func setupLocalVideo(view: UIView) {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.view = view
        videoCanvas.renderMode = .hidden
        agoraEngine?.setupLocalVideo(videoCanvas)
    }
    
    func setupRemoteVideo(uid: UInt, view: UIView) {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.view = view
        videoCanvas.renderMode = .hidden
        agoraEngine?.setupRemoteVideo(videoCanvas)
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgoraManager: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        remoteUsers.append(uid)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        if let index = remoteUsers.firstIndex(of: uid) {
            remoteUsers.remove(at: index)
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        error = "Error: \(errorCode.rawValue)"
    }
} 
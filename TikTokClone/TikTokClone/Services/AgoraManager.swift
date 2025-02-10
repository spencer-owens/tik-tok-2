import Foundation
import AgoraRtcKit
import SwiftUI

class AgoraManager: NSObject, ObservableObject {
    static let shared = AgoraManager()
    
    @Published var isInStream: Bool = false
    @Published var error: String?
    @Published var remoteUsers: [UInt] = []
    @Published var isConnected: Bool = false
    @Published var remoteUsersBPM: [UInt: Int] = [:] // Store remote users' BPM
    
    private var agoraEngine: AgoraRtcEngineKit?
    private let appId = "100058b20ef3410997a741498f12e668"
    private var currentChannelName: String?
    private var currentToken: String?
    private var streamId: Int = 0 // Store the data stream ID
    private var periodicUpdateTimer: Timer?
    private var currentBPM: Int = 0 // Store current BPM for periodic updates
    
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
        print("🎟️ Joining channel: \(channelName) as \(role == .broadcaster ? "broadcaster" : "audience")")
        
        // If already connected to this channel, just update role
        if isConnected && channelName == currentChannelName {
            setClientRole(role)
            return
        }
        
        // Store current connection info
        currentChannelName = channelName
        currentToken = token
        
        // Disable all audio
        agoraEngine?.muteAllRemoteAudioStreams(true)
        agoraEngine?.enableLocalAudio(false)
        agoraEngine?.muteLocalAudioStream(true)
        agoraEngine?.setDefaultAudioRouteToSpeakerphone(false)
        
        // Set channel profile first
        agoraEngine?.setChannelProfile(.liveBroadcasting)
        
        // Set client role before joining
        agoraEngine?.setClientRole(role)
        
        // Enable video module
        agoraEngine?.enableVideo()
        
        // Configure video encoding parameters for 60 FPS
        let videoConfig = AgoraVideoEncoderConfiguration()
        videoConfig.frameRate = .fps60
        videoConfig.dimensions = CGSize(width: 1920, height: 1080) // 1080p
        videoConfig.bitrate = AgoraVideoBitrateStandard
        agoraEngine?.setVideoEncoderConfiguration(videoConfig)
        
        // Create data stream for BPM
        let config = AgoraDataStreamConfig()
        config.ordered = true
        
        var streamIdResult = 0
        let createStreamResult = agoraEngine?.createDataStream(&streamIdResult, config: config)
        self.streamId = streamIdResult
        print("🔧 Created data stream with ID: \(streamId), result: \(String(describing: createStreamResult))")
        
        // Join the channel
        agoraEngine?.joinChannel(
            byToken: token,
            channelId: channelName,
            info: nil,
            uid: 0,
            joinSuccess: { [weak self] (channel, uid, elapsed) in
                print("✅ Successfully joined channel: \(channel)")
                self?.isInStream = role == .broadcaster
                self?.isConnected = true
                
                // Setup local video if broadcaster
                if role == .broadcaster {
                    print("🎥 Setting up local video after join")
                    let videoCanvas = AgoraRtcVideoCanvas()
                    videoCanvas.uid = 0
                    videoCanvas.renderMode = .hidden
                    self?.agoraEngine?.setupLocalVideo(videoCanvas)
                }
            }
        )
    }
    
    // Send BPM data to other users
    func sendBPMUpdate(_ bpm: Int) {
        guard isConnected, streamId != 0 else {
            print("❌ Cannot send BPM: not connected or no stream ID")
            return
        }
        
        currentBPM = bpm // Store current BPM
        print("📤 Attempting to send BPM update: \(bpm)")
        
        // Create a simple JSON structure with explicit type
        let data: [String: Any] = [
            "type": "bpm",
            "value": bpm
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            // Send the data through the stream
            print("📝 Sending JSON data: \(jsonString)")
            let result = agoraEngine?.sendStreamMessage(streamId, data: jsonString.data(using: .utf8) ?? Data())
            print("📨 Send result: \(result == 0 ? "Success" : "Failed with code: \(String(describing: result))")")
        } else {
            print("❌ Failed to serialize BPM data")
        }
    }
    
    private func startPeriodicUpdates() {
        print("⏰ Starting periodic BPM updates")
        periodicUpdateTimer?.invalidate()
        periodicUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isInStream else { return }
            print("⏰ Sending periodic BPM update: \(self.currentBPM)")
            self.sendBPMUpdate(self.currentBPM)
        }
    }
    
    private func stopPeriodicUpdates() {
        print("⏹️ Stopping periodic BPM updates")
        periodicUpdateTimer?.invalidate()
        periodicUpdateTimer = nil
    }
    
    func leaveChannel() {
        stopPeriodicUpdates()
        agoraEngine?.leaveChannel(nil)
        isInStream = false
        isConnected = false
        currentChannelName = nil
        currentToken = nil
        remoteUsers.removeAll()
        remoteUsersBPM.removeAll() // Clear stored BPM data
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
    
    func setClientRole(_ role: AgoraClientRole) {
        guard isConnected else {
            print("❌ Cannot set role: not connected")
            return
        }
        
        print("🎭 Setting client role to: \(role == .broadcaster ? "broadcaster" : "audience")")
        agoraEngine?.setClientRole(role)
        
        if role == .broadcaster {
            // Enable video module
            agoraEngine?.enableVideo()
            
            print("🎥 Setting up local video for broadcaster")
            let videoCanvas = AgoraRtcVideoCanvas()
            videoCanvas.uid = 0
            videoCanvas.renderMode = .hidden
            agoraEngine?.setupLocalVideo(videoCanvas)
            
            // Create new data stream when becoming broadcaster
            let config = AgoraDataStreamConfig()
            config.ordered = true
            
            var streamIdResult = 0
            let createStreamResult = agoraEngine?.createDataStream(&streamIdResult, config: config)
            self.streamId = streamIdResult
            print("🔧 Created data stream with ID: \(streamId), result: \(String(describing: createStreamResult))")
            
            // Start periodic updates
            startPeriodicUpdates()
        } else {
            // Stop periodic updates when becoming audience
            stopPeriodicUpdates()
        }
        
        isInStream = role == .broadcaster
        print("🎬 Updated isInStream to: \(isInStream)")
    }
    
    // Helper method to reconnect if needed
    func ensureConnection(token: String, channelName: String, as role: AgoraClientRole) {
        if !isConnected {
            joinChannel(token: token, channelName: channelName, as: role)
        }
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgoraManager: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("👥 Remote user joined: \(uid)")
        remoteUsers.append(uid)
        
        // If we're broadcasting, send our BPM to the new user
        if isInStream {
            print("👋 New user joined, sending current BPM: \(currentBPM)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.sendBPMUpdate(self?.currentBPM ?? 0)
            }
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("👋 Remote user left: \(uid)")
        if let index = remoteUsers.firstIndex(of: uid) {
            remoteUsers.remove(at: index)
            remoteUsersBPM.removeValue(forKey: uid)
            print("🗑️ Removed BPM data for uid: \(uid)")
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        error = "Error: \(errorCode.rawValue)"
    }
    
    // Handle incoming BPM data
    func rtcEngine(_ engine: AgoraRtcEngineKit, receiveStreamMessageFromUid uid: UInt, streamId: Int, data: Data) {
        print("📥 Received data stream message from uid: \(uid)")
        
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📝 Received JSON string: \(jsonString)")
            
            if let jsonData = jsonString.data(using: .utf8),
               let message = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               message["type"] as? String == "bpm",
               let bpm = message["value"] as? Int {
                
                print("💓 Successfully parsed BPM: \(bpm) from uid: \(uid)")
                DispatchQueue.main.async {
                    self.remoteUsersBPM[uid] = bpm
                    print("✅ Updated remoteUsersBPM[\(uid)] = \(bpm)")
                }
            } else {
                print("❌ Failed to parse BPM data from JSON")
            }
        } else {
            print("❌ Failed to decode received data as string")
        }
    }
} 
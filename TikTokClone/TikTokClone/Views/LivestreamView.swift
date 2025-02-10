import SwiftUI
import AgoraRtcKit


struct AgoraVideoView: UIViewRepresentable {
    let uid: UInt
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        if uid == 0 {
            AgoraManager.shared.setupLocalVideo(view: view)
        } else {
            AgoraManager.shared.setupRemoteVideo(uid: uid, view: view)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct LivestreamView: View {
    @StateObject private var agoraManager = AgoraManager.shared
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var isBroadcasting = false
    
    private let channelName = "test-channel"
    
    var body: some View {
        ZStack {
            // Main content
            ScrollView {
                VStack(spacing: 20) {
                    // My Livestream Section
                    VStack(alignment: .leading) {
                        Text("My Stream")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ZStack {
                            if isBroadcasting {
                                // Active stream view
                                AgoraVideoView(uid: 0)
                                    .frame(height: 300)
                                    .cornerRadius(10)
                            } else {
                                // Placeholder for inactive stream
                                Rectangle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(height: 300)
                                    .cornerRadius(10)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "video.fill")
                                                .font(.largeTitle)
                                                .foregroundColor(.white.opacity(0.7))
                                            Text("Start Streaming")
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    )
                            }
                            
                            // Stream control button
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        isBroadcasting.toggle()
                                        if isBroadcasting {
                                            print("🎬 Starting broadcast")
                                            agoraManager.setClientRole(.broadcaster)
                                            // Send initial BPM after a short delay to ensure stream is ready
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                print("🏃‍♂️ Sending initial BPM: \(healthKitManager.currentBPM)")
                                                agoraManager.sendBPMUpdate(healthKitManager.currentBPM)
                                            }
                                        } else {
                                            print("⏹️ Stopping broadcast")
                                            agoraManager.setClientRole(.audience)
                                        }
                                    }) {
                                        Image(systemName: isBroadcasting ? "video.slash.fill" : "video.fill")
                                            .font(.title2)
                                            .foregroundColor(isBroadcasting ? .red : .green)
                                            .padding()
                                            .background(Color.white.opacity(0.2))
                                            .clipShape(Circle())
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                    .padding(.top)
                    
                    // Other Streams Section
                    VStack(alignment: .leading) {
                        Text("Live Now")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        VStack {
                            if agoraManager.remoteUsers.isEmpty {
                                Text("No active streams")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 10) {
                                    ForEach(agoraManager.remoteUsers, id: \.self) { uid in
                                        ZStack {
                                            AgoraVideoView(uid: uid)
                                                .frame(height: 200)
                                                .cornerRadius(10)
                                            
                                            // Display remote user's BPM if available
                                            if let bpm = agoraManager.remoteUsersBPM[uid] {
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                        HStack(spacing: 4) {
                                                            Image(systemName: "heart.fill")
                                                                .foregroundColor(.red)
                                                            Text("\(bpm)")
                                                                .foregroundColor(.white)
                                                        }
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .padding(6)
                                                        .background(Color.black.opacity(0.6))
                                                        .cornerRadius(8)
                                                        .padding(8)
                                                    }
                                                    Spacer()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // Heart Rate Display in top-right corner
            VStack {
                HStack {
                    Spacer()
                    HeartRateView()
                }
                .padding(.top, 50)
                .padding(.horizontal)
                
                Spacer()
            }
            
            // Error alert
            if let error = agoraManager.error {
                Text(error)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                    .transition(.move(edge: .top))
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .onAppear {
            print("📱 LivestreamView appeared")
            // Ensure we're connected as audience
            agoraManager.ensureConnection(
                token: Secrets.Agora.getToken(channelName: channelName),
                channelName: channelName,
                as: .audience
            )
        }
        .onDisappear {
            print("👋 LivestreamView disappeared")
            if isBroadcasting {
                print("⏹️ Stopping broadcast on disappear")
                isBroadcasting = false
                agoraManager.setClientRole(.audience)
            }
        }
        .onChange(of: healthKitManager.currentBPM) { newValue in
            // Send BPM updates when broadcasting
            if isBroadcasting {
                print("❤️ Broadcasting BPM update: \(newValue)")
                agoraManager.sendBPMUpdate(newValue)
            }
        }
    }
} 
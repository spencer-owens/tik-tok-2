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
    @Environment(\.presentationMode) var presentationMode
    
    private let token = "007eJxTYFA+NneTdtR6ds6lr4VnSFneeLNi40Wu8J1Tor79ff30bttBBQZDAwMDU4skI4PUNGMTQwNLS/NEcxNDE0uLNEOjVDMzC5nXi9MbAhkZEgIfMTMyQCCIz8NQklpcopuckZiXl5rDwAAAyzMj6w=="
    private let channelName = "test-channel"
    
    var body: some View {
        ZStack {
            // Main content
            VStack {
                // Local video view (when broadcasting)
                if agoraManager.isInStream {
                    AgoraVideoView(uid: 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(10)
                        .padding()
                }
                
                // Remote video grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(agoraManager.remoteUsers, id: \.self) { uid in
                        AgoraVideoView(uid: uid)
                            .frame(height: 200)
                            .cornerRadius(10)
                    }
                }
                .padding()
                
                // Controls
                HStack(spacing: 20) {
                    Button(action: {
                        if agoraManager.isInStream {
                            agoraManager.leaveChannel()
                        } else {
                            agoraManager.joinChannel(
                                token: token,
                                channelName: channelName,
                                as: .broadcaster
                            )
                        }
                    }) {
                        Image(systemName: agoraManager.isInStream ? "video.slash.fill" : "video.fill")
                            .font(.title)
                            .foregroundColor(agoraManager.isInStream ? .red : .green)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        agoraManager.leaveChannel()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 30)
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
        .contentShape(Rectangle())
        .onDisappear {
            agoraManager.leaveChannel()
        }
    }
} 
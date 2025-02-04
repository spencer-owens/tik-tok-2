import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var appwriteManager: AppwriteManager
    
    var body: some View {
        GeometryReader { geometry in
            TabView {
                // Placeholder video cells
                ForEach(0..<5) { index in
                    VideoPlaceholderCell(index: index)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            // Overlay buttons
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    // Logout button (temporary for testing)
                    Button(action: {
                        Task {
                            await appwriteManager.logout()
                        }
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
            }
        }
    }
}

// Placeholder cell for videos
struct VideoPlaceholderCell: View {
    let index: Int
    
    var body: some View {
        ZStack {
            Color.black
            
            VStack(spacing: 20) {
                Text("Video \(index + 1)")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Image(systemName: "play.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Swipe up for next video")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Right side buttons (likes, comments, etc.)
            VStack {
                Spacer()
                VStack(spacing: 20) {
                    Button(action: {}) {
                        VStack {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 28))
                            Text("150K")
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {}) {
                        VStack {
                            Image(systemName: "message.fill")
                                .font(.system(size: 28))
                            Text("1.2K")
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {}) {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 28))
                            Text("Share")
                                .font(.caption)
                        }
                    }
                }
                .foregroundColor(.white)
                .padding(.trailing, 20)
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    FeedView()
        .environmentObject(AppwriteManager.shared)
} 
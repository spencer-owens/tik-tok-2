import SwiftUI

struct LandingView: View {
    @State private var yOffset: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0
    @State private var showTrail = false
    @State private var trailOpacity: Double = 0
    @State private var circleScale: CGFloat = 0.8
    @State private var circleOpacity: Double = 0
    
    // Calculate a value that ensures the figure goes completely off screen
    private var offScreenOffset: CGFloat {
        -(UIScreen.main.bounds.height + 200) // Add extra padding to ensure it's fully off screen
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Static circle
            Circle()
                .stroke(.white, lineWidth: 3)
                .frame(width: 140, height: 140)
                .scaleEffect(circleScale)
                .opacity(circleOpacity)
            
            // Enhanced trail effect
            if showTrail {
                // Main rocket trail
                ForEach(0..<20) { index in
                    Circle()
                        .fill(.white.opacity(0.4))
                        .frame(width: 12 - CGFloat(index) * 0.4, height: 12 - CGFloat(index) * 0.4)
                        .offset(y: yOffset + CGFloat(index * 12))
                        .opacity(trailOpacity * (1 - Double(index) / 20))
                        .blur(radius: 2)
                }
                
                // Secondary particles
                ForEach(0..<10) { index in
                    Circle()
                        .fill(.orange.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .offset(
                            x: CGFloat.random(in: -20...20),
                            y: yOffset + CGFloat(index * 15)
                        )
                        .opacity(trailOpacity * (1 - Double(index) / 10))
                        .blur(radius: 1)
                }
            }
            
            // Main figure
            Image(systemName: "figure.mind.and.body")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundColor(.white)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
                .offset(y: yOffset)
                .opacity(opacity)
        }
        .onAppear {
            // Fade in figure and circle
            withAnimation(.easeIn(duration: 0.4)) {
                opacity = 1
                circleOpacity = 1
            }
            
            // Circle appears with slight scale animation
            withAnimation(.spring(duration: 0.6)) {
                circleScale = 1.0
            }
            
            // Longer pause before squish
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                // Anticipation animation
                withAnimation(.easeInOut(duration: 0.5)) {
                    yOffset = 20
                    scale = 0.9
                }
                
                // Blast off with longer duration!
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showTrail = true
                    
                    withAnimation(.spring(duration: 2.2, bounce: 0.2)) {
                        yOffset = offScreenOffset
                        scale = 0.5
                        rotation = 15
                    }
                    
                    // Fade in trail
                    withAnimation(.easeIn(duration: 0.4)) {
                        trailOpacity = 1
                    }
                }
            }
        }
    }
}

#Preview {
    LandingView()
} 
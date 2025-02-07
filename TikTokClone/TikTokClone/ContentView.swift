import SwiftUI

struct ContentView: View {
    @State private var showMainView = false
    
    var body: some View {
        ZStack {
            if showMainView {
                MainView()
                    .transition(.move(edge: .trailing))
            } else {
                LandingView()
                    .transition(.opacity)
                    .onAppear {
                        // Transition to main view after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                showMainView = true
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppwriteManager.shared)
}
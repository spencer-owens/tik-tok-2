import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Hello, butt Clone!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Ready to start building!")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("TikTok Clone")
        }
    }
}

#Preview {
    ContentView()
}
import SwiftUI

struct ContentView: View {
    var body: some View {
        MainView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppwriteManager.shared)
}
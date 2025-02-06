import SwiftUI
import AgoraRtcKit


enum MainTab: Int, CaseIterable {
    case schedule = 0
    case activity
    case liveStreams
    case peaceful
    
    var title: String {
        switch self {
        case .schedule: return "Schedule"
        case .activity: return "Activity"
        case .liveStreams: return "Live"
        case .peaceful: return "Peaceful"
        }
    }
}

struct MainView: View {
    @State private var selectedTab: MainTab = .schedule
    @GestureState private var dragOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(MainTab.allCases, id: \.rawValue) { tab in
                    tabView(for: tab)
                        .frame(width: geometry.size.width)
                }
            }
            .offset(x: -CGFloat(selectedTab.rawValue) * geometry.size.width)
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let threshold = geometry.size.width * 0.25
                        var newIndex = CGFloat(selectedTab.rawValue) - value.translation.width / geometry.size.width
                        
                        if abs(value.translation.width) > threshold {
                            newIndex = newIndex.rounded()
                        } else {
                            newIndex = CGFloat(selectedTab.rawValue)
                        }
                        
                        newIndex = min(CGFloat(MainTab.allCases.count - 1), max(0, newIndex))
                        withAnimation {
                            selectedTab = MainTab(rawValue: Int(newIndex)) ?? .schedule
                        }
                    }
            )
            .animation(.interactiveSpring(), value: dragOffset)
        }
    }
    
    @ViewBuilder
    private func tabView(for tab: MainTab) -> some View {
        switch tab {
        case .schedule:
            ScheduleView()
        case .activity:
            ActivityView(isActive: Binding(
                get: { selectedTab == .activity },
                set: { _ in }
            ))
        case .liveStreams:
            LivestreamView()
        case .peaceful:
            PlaceholderView(title: "Peaceful View", subtitle: "Coming soon")
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title)
            Text(subtitle)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    MainView()
} 
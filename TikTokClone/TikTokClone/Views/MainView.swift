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
    
    var icon: String {
        switch self {
        case .schedule: return "calendar"
        case .activity: return "figure.walk"
        case .liveStreams: return "video.fill"
        case .peaceful: return "leaf.fill"
        }
    }
}

struct MainView: View {
    @State private var selectedTab: MainTab = .schedule
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleView()
                .tag(MainTab.schedule)
                .tabItem {
                    Label(MainTab.schedule.title, systemImage: MainTab.schedule.icon)
                }
            
            ActivityView(isActive: Binding(
                get: { selectedTab == .activity },
                set: { _ in }
            ))
                .tag(MainTab.activity)
                .tabItem {
                    Label(MainTab.activity.title, systemImage: MainTab.activity.icon)
                }
            
            LivestreamView()
                .tag(MainTab.liveStreams)
                .tabItem {
                    Label(MainTab.liveStreams.title, systemImage: MainTab.liveStreams.icon)
                }
            
            PeacefulView()
                .tag(MainTab.peaceful)
                .tabItem {
                    Label(MainTab.peaceful.title, systemImage: MainTab.peaceful.icon)
                }
        }
        .tint(.white)
        .onAppear {
            // Style the tab bar to be dark
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .black
            
            // Style the selected and unselected items
            appearance.stackedLayoutAppearance.selected.iconColor = .white
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.stackedLayoutAppearance.normal.iconColor = .gray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
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
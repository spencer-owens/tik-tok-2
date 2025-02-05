import SwiftUI

struct ScheduleItem: Identifiable {
    let id = UUID()
    let time: Date
    let activity: String
    let type: ActivityType
    
    enum ActivityType {
        case meditation
        case walking
        case meal
        case other
    }
}

struct ScheduleView: View {
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    let schedule: [ScheduleItem] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let scheduleData: [(time: String, activity: String, type: ScheduleItem.ActivityType)] = [
            ("06:00", "Wake up", .other),
            ("06:30", "Guided meditation", .meditation),
            ("07:15", "Breakfast", .meal),
            ("08:00", "Walking meditation", .walking),
            ("08:30", "Guided meditation", .meditation),
            ("09:30", "Walking meditation", .walking),
            ("10:00", "Guided meditation", .meditation),
            ("11:00", "Walking meditation", .walking),
            ("11:30", "Lunch", .meal),
            ("13:00", "Guided meditation", .meditation),
            ("14:00", "Walking meditation", .walking),
            ("14:30", "Guided meditation", .meditation),
            ("15:30", "Walking meditation", .walking),
            ("16:00", "Guided meditation", .meditation),
            ("17:00", "Light dinner", .meal),
            ("18:00", "Final meditation", .meditation),
            ("19:00", "Rest", .other)
        ]
        
        return scheduleData.compactMap { data in
            if let date = formatter.date(from: data.time) {
                let fullDate = calendar.date(
                    bySettingHour: calendar.component(.hour, from: date),
                    minute: calendar.component(.minute, from: date),
                    second: 0,
                    of: today
                )
                return fullDate.map { ScheduleItem(time: $0, activity: data.activity, type: data.type) }
            }
            return nil
        }
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Daily Schedule")
                .font(.title)
                .padding()
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(schedule) { item in
                            ScheduleItemView(item: item, isCurrentActivity: isCurrentActivity(item))
                                .id(item.id)
                        }
                    }
                }
                .onChange(of: currentTime) { _ in
                    if let currentItem = schedule.first(where: { isCurrentActivity($0) }) {
                        withAnimation {
                            proxy.scrollTo(currentItem.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    private func isCurrentActivity(_ item: ScheduleItem) -> Bool {
        let calendar = Calendar.current
        let currentDate = Date()
        
        let itemIndex = schedule.firstIndex(where: { $0.id == item.id }) ?? 0
        let nextItemIndex = itemIndex + 1
        
        let itemTime = calendar.dateComponents([.hour, .minute], from: item.time)
        let currentTime = calendar.dateComponents([.hour, .minute], from: currentDate)
        
        if nextItemIndex < schedule.count {
            let nextItem = schedule[nextItemIndex]
            let nextTime = calendar.dateComponents([.hour, .minute], from: nextItem.time)
            
            return isTime(currentTime, betweenOrEqual: itemTime, and: nextTime)
        } else {
            return isTime(currentTime, afterOrEqual: itemTime)
        }
    }
    
    private func isTime(_ time: DateComponents, betweenOrEqual start: DateComponents, and end: DateComponents) -> Bool {
        let timeMinutes = time.hour! * 60 + time.minute!
        let startMinutes = start.hour! * 60 + start.minute!
        let endMinutes = end.hour! * 60 + end.minute!
        
        return timeMinutes >= startMinutes && timeMinutes < endMinutes
    }
    
    private func isTime(_ time: DateComponents, afterOrEqual start: DateComponents) -> Bool {
        let timeMinutes = time.hour! * 60 + time.minute!
        let startMinutes = start.hour! * 60 + start.minute!
        
        return timeMinutes >= startMinutes
    }
}

struct ScheduleItemView: View {
    let item: ScheduleItem
    let isCurrentActivity: Bool
    
    var body: some View {
        HStack {
            Text(timeString)
                .frame(width: 80)
                .font(.system(.body, design: .monospaced))
            
            Rectangle()
                .frame(width: 2)
                .foregroundColor(isCurrentActivity ? .blue : .gray)
            
            Text(item.activity)
                .padding(.leading)
            
            Spacer()
        }
        .frame(height: 44)
        .background(isCurrentActivity ? Color.blue.opacity(0.1) : Color.clear)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: item.time)
    }
}

#Preview {
    ScheduleView()
} 
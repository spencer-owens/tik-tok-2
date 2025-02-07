import HealthKit
import SwiftUI

final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    @Published var currentBPM: Int = 0
    @Published var isLoading: Bool = true
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    @AppStorage("lastKnownBPM") private var lastKnownBPM: Int = 0
    
    private var observerQuery: HKObserverQuery?
    private var anchor: HKQueryAnchor?
    
    private init() {
        // Initialize with last known BPM
        currentBPM = lastKnownBPM
        
        // Setup notification observers for app lifecycle
        setupAppLifecycleObservers()
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBackgroundTransition),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForegroundTransition),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func handleBackgroundTransition() {
        stopObservingHeartRate()
    }
    
    @objc private func handleForegroundTransition() {
        if authorizationStatus == .sharingAuthorized {
            startObserver()
        }
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("Health data not available on this device.")
            return
        }
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            print("Could not create heart rate quantity type.")
            return
        }
        
        // Check current authorization status
        let status = healthStore.authorizationStatus(for: heartRateType)
        self.authorizationStatus = status
        
        if status == .sharingAuthorized {
            print("✅ HealthKit already authorized.")
            startObserver()
            return
        }
        
        let toRead: Set = [heartRateType]
        
        healthStore.requestAuthorization(toShare: [], read: toRead) { [weak self] success, error in
            if let error = error {
                print("HealthKit authorization error:", error.localizedDescription)
            }
            
            DispatchQueue.main.async {
                if success {
                    print("✅ HealthKit authorization granted for heart rate.")
                    self?.authorizationStatus = .sharingAuthorized
                    self?.startObserver()
                } else {
                    print("❌ HealthKit authorization was not granted.")
                    self?.authorizationStatus = .sharingDenied
                }
            }
        }
    }
    
    private func startObserver() {
        // Clean up any existing observer first
        stopObservingHeartRate()
        
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        // Observer query – triggers whenever new heart rate data is saved
        observerQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                print("Observer query error:", error.localizedDescription)
                completionHandler()
                return
            }
            
            print("🔔 Observer query invoked – new heart rate data available.")
            // Fetch the latest BPM after any new sample
            self?.fetchLatestBPM()
            
            // Notify HealthKit that we're done processing
            completionHandler()
        }
        
        if let observerQuery = observerQuery {
            healthStore.execute(observerQuery)
            print("🟢 Observer query is now running.")
        }
        
        // Fetch initial BPM
        fetchLatestBPM()
    }
    
    private func fetchLatestBPM() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType,
                                predicate: nil,
                                limit: 1,
                                sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            
            if let error = error {
                print("Error fetching latest BPM:", error.localizedDescription)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
                return
            }
            
            let bpmValue = Int(sample.quantity.doubleValue(for: .count().unitDivided(by: .minute())))
            
            DispatchQueue.main.async {
                self?.currentBPM = bpmValue
                self?.lastKnownBPM = bpmValue // Cache the value
                self?.isLoading = false
                print("💓 Updated currentBPM to \(bpmValue)")
            }
        }
        
        healthStore.execute(query)
    }
    
    func stopObservingHeartRate() {
        if let observerQuery = observerQuery {
            healthStore.stop(observerQuery)
            print("🛑 Stopped Heart Rate Observer Query.")
            self.observerQuery = nil
        }
    }
    
    func openHealthApp() {
        // Try the direct heart rate page first
        if let url = URL(string: "x-apple-health://health/data/record/detail/HeartRate") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return
            }
        }
        
        // Fallback to main Health app
        if let url = URL(string: "x-apple-health://") {
            UIApplication.shared.open(url)
        }
    }
    
    deinit {
        stopObservingHeartRate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Heart Rate Display View
struct HeartRateView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager
    
    var body: some View {
        Button(action: {
            if healthKitManager.authorizationStatus != .sharingAuthorized {
                healthKitManager.requestAuthorization()
            } else {
                healthKitManager.openHealthApp()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                if healthKitManager.isLoading {
                    // Show just the heart icon when loading
                    EmptyView()
                } else {
                    Text("\(healthKitManager.currentBPM)")
                        .foregroundColor(.white)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(20)
        }
    }
} 
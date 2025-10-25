import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Models
struct User: Identifiable, Hashable, Equatable {
    let id = UUID()
    let name: String
    let location: CLLocationCoordinate2D?
    let profileEmoji: String?
    
    init(name: String, location: CLLocationCoordinate2D?, profileEmoji: String? = nil) {
        self.name = name
        self.location = location
        self.profileEmoji = profileEmoji ?? "👤"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}

struct HangoutSession: Identifiable, Hashable, Equatable {
    let id = UUID()
    let participants: [User]
    let startTime: Date
    let endTime: Date?
    let location: CLLocationCoordinate2D?
    let duration: TimeInterval
    let isActive: Bool
    
    init(participants: [User], startTime: Date, endTime: Date? = nil, location: CLLocationCoordinate2D? = nil, isActive: Bool = false) {
        self.participants = participants
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.isActive = isActive
        self.duration = endTime?.timeIntervalSince(startTime) ?? 0
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(startTime)
    }
    
    static func == (lhs: HangoutSession, rhs: HangoutSession) -> Bool {
        return lhs.id == rhs.id && lhs.startTime == rhs.startTime
    }
}

// MARK: - Services
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates(handler: @escaping (CLLocation) -> Void) {
        locationUpdateHandler = handler
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationUpdateHandler = nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = location
        }
        locationUpdateHandler?(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
    }
}

class HangoutEngine: ObservableObject {
    static let shared = HangoutEngine()
    
    private init() {}
    
    func getActiveHangouts() -> [HangoutSession] {
        // Return mock active hangouts - friends currently hanging out
        return [
            HangoutSession(
                participants: [
                    User(name: "Sarah", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), profileEmoji: "👩‍💼"),
                    User(name: "Mike", location: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294), profileEmoji: "👨‍💻")
                ],
                startTime: Date().addingTimeInterval(-300), // 5 minutes ago
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                isActive: true
            ),
            HangoutSession(
                participants: [
                    User(name: "Emma", location: CLLocationCoordinate2D(latitude: 37.7949, longitude: -122.4194), profileEmoji: "👩‍🎓"),
                    User(name: "Alex", location: CLLocationCoordinate2D(latitude: 37.7549, longitude: -122.4094), profileEmoji: "👨‍🍳")
                ],
                startTime: Date().addingTimeInterval(-600), // 10 minutes ago
                location: CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4190),
                isActive: true
            )
        ]
    }
    
    func getWeeklyHangouts() -> [HangoutSession] {
        // Return mock weekly hangouts - friends who hung out this week
        return [
            // You hung out with Sarah yesterday
            HangoutSession(
                participants: [
                    User(name: "You", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), profileEmoji: "👤"),
                    User(name: "Sarah", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), profileEmoji: "👩‍💼")
                ],
                startTime: Date().addingTimeInterval(-86400), // Yesterday
                endTime: Date().addingTimeInterval(-86400 + 3600), // 1 hour duration
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            ),
            // Sarah and Josh hung out together
            HangoutSession(
                participants: [
                    User(name: "Sarah", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), profileEmoji: "👩‍💼"),
                    User(name: "Josh", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.3994), profileEmoji: "👨‍🎨")
                ],
                startTime: Date().addingTimeInterval(-172800), // 2 days ago
                endTime: Date().addingTimeInterval(-172800 + 7200), // 2 hour duration
                location: CLLocationCoordinate2D(latitude: 37.7755, longitude: -122.4200)
            ),
            // Mike and Lisa hung out together
            HangoutSession(
                participants: [
                    User(name: "Mike", location: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294), profileEmoji: "👨‍💻"),
                    User(name: "Lisa", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4394), profileEmoji: "👩‍⚕️")
                ],
                startTime: Date().addingTimeInterval(-259200), // 3 days ago
                endTime: Date().addingTimeInterval(-259200 + 5400), // 1.5 hour duration
                location: CLLocationCoordinate2D(latitude: 37.7740, longitude: -122.4190)
            ),
            // You hung out with Emma and Alex
            HangoutSession(
                participants: [
                    User(name: "You", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), profileEmoji: "👤"),
                    User(name: "Emma", location: CLLocationCoordinate2D(latitude: 37.7949, longitude: -122.4194), profileEmoji: "👩‍🎓"),
                    User(name: "Alex", location: CLLocationCoordinate2D(latitude: 37.7549, longitude: -122.4094), profileEmoji: "👨‍🍳")
                ],
                startTime: Date().addingTimeInterval(-345600), // 4 days ago
                endTime: Date().addingTimeInterval(-345600 + 7200), // 2 hour duration
                location: CLLocationCoordinate2D(latitude: 37.7745, longitude: -122.4190)
            )
        ]
    }
    
    func getTotalHangoutTime(with friend: User) -> TimeInterval {
        // Placeholder implementation
        return 7200 // 2 hours
    }
}

// MARK: - Components
struct CircleMemberAnnotation: View {
    let member: User
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                
                Text(member.profileEmoji ?? "👤")
                    .font(.system(size: 20))
            }
        }
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.2), value: member.name)
    }
}

struct StatsOverlayCard: View {
    let activeHangouts: [HangoutSession]
    let weeklyHangouts: [HangoutSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Active hangouts
            if !activeHangouts.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                    Text("Currently with \(activeHangouts.first?.participants.count ?? 0) friends")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            
            // Weekly summary
            let totalHours = weeklyHangouts.reduce(0) { $0 + $1.duration } / 3600
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text("\(String(format: "%.1f", totalHours)) hours this week")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            // Top hangout buddy
            if let topFriend = getTopHangoutBuddy() {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.orange)
                    Text("Most time with \(topFriend.name)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
    
    private func getTopHangoutBuddy() -> User? {
        // Simple implementation - return first participant from first hangout
        return weeklyHangouts.first?.participants.first
    }
}

struct CustomMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let circleMembers: [User]
    let activeHangouts: [HangoutSession]
    let weeklyHangouts: [HangoutSession]
    let onFriendTap: (User) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region
        mapView.setRegion(region, animated: true)
        
        // Remove existing annotations and overlays
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // Add friend annotations
        for member in circleMembers {
            if let location = member.location {
                let annotation = FriendAnnotation(member: member)
                annotation.coordinate = location
                mapView.addAnnotation(annotation)
            }
        }
        
        // Add connection lines as proper map overlays
        addConnectionLines(to: mapView)
    }
    
    private func addConnectionLines(to mapView: MKMapView) {
        // Connect YOU to all your friends (since they're all your friends) - ALL GREEN
        if let you = circleMembers.first(where: { $0.name == "You" }),
           let yourLocation = you.location {
            for friend in circleMembers {
                if friend.name != "You", let friendLocation = friend.location {
                    let coordinates = [yourLocation, friendLocation]
                    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    polyline.title = "friend" // Mark as friend connection
                    mapView.addOverlay(polyline)
                }
            }
        }
        
        // Add active hangout lines (solid green) - only for non-You connections
        for hangout in activeHangouts {
            if hangout.participants.count >= 2 {
                for i in 0..<hangout.participants.count-1 {
                    let member1 = hangout.participants[i]
                    let member2 = hangout.participants[i+1]
                    
                    // Skip if either participant is "You" (already connected above)
                    if member1.name == "You" || member2.name == "You" {
                        continue
                    }
                    
                    if let loc1 = member1.location, let loc2 = member2.location {
                        let coordinates = [loc1, loc2]
                        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                        polyline.title = "active" // Mark as active for styling
                        mapView.addOverlay(polyline)
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: CustomMapView
        
        init(_ parent: CustomMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let friendAnnotation = annotation as? FriendAnnotation {
                let identifier = "FriendAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = false
                    annotationView?.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                } else {
                    annotationView?.annotation = annotation
                }
                
                // Clear existing subviews
                annotationView?.subviews.forEach { $0.removeFromSuperview() }
                
                // Create custom annotation view using UIKit
                let customView = FriendAnnotationView(member: friendAnnotation.member) {
                    self.parent.onFriendTap(friendAnnotation.member)
                }
                
                annotationView?.addSubview(customView)
                customView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    customView.centerXAnchor.constraint(equalTo: annotationView!.centerXAnchor),
                    customView.centerYAnchor.constraint(equalTo: annotationView!.centerYAnchor),
                    customView.widthAnchor.constraint(equalToConstant: 40),
                    customView.heightAnchor.constraint(equalToConstant: 40)
                ])
                
                return annotationView
            }
            
            return nil
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                // ALL LINES ARE GREEN - friends and active hangouts
                renderer.strokeColor = UIColor.systemGreen
                renderer.lineWidth = 2
                renderer.lineDashPattern = nil
                
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

class FriendAnnotation: NSObject, MKAnnotation {
    let member: User
    var coordinate: CLLocationCoordinate2D
    
    init(member: User) {
        self.member = member
        self.coordinate = member.location ?? CLLocationCoordinate2D()
        super.init()
    }
}

class FriendAnnotationView: UIView {
    let member: User
    let onTap: () -> Void
    
    init(member: User, onTap: @escaping () -> Void) {
        self.member = member
        self.onTap = onTap
        super.init(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Create circular background
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.systemBlue
        backgroundView.layer.cornerRadius = 20
        backgroundView.layer.borderWidth = 2
        backgroundView.layer.borderColor = UIColor.white.cgColor
        
        addSubview(backgroundView)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            backgroundView.widthAnchor.constraint(equalToConstant: 40),
            backgroundView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Create emoji label
        let emojiLabel = UILabel()
        emojiLabel.text = member.profileEmoji ?? "👤"
        emojiLabel.font = UIFont.systemFont(ofSize: 20)
        emojiLabel.textAlignment = .center
        
        addSubview(emojiLabel)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emojiLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    @objc private func handleTap() {
        print("🎯 FriendAnnotationView tapped for: \(member.name)")
        onTap()
    }
}


struct FriendDetailSheet: View {
    let friend: User
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    VStack(spacing: 12) {
                        Text(friend.profileEmoji ?? "👤")
                            .font(.system(size: 60))
                        
                        Text(friend.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(getLocationString())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Updated 1 minute ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    // Action Buttons Section
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            // Contact Button
                            Button(action: {
                                // Contact action
                            }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                            .font(.title2)
                                    }
                                    
                                    Text("Contact")
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Spacer()
                            
                            // Directions Button
                            Button(action: {
                                // Directions action
                            }) {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                            .foregroundColor(.white)
                                            .font(.title2)
                                    }
                                    
                                    VStack(spacing: 2) {
                                        Text("Directions")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        
                                        Text("2.3 km")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                    
                    // Hangout Stats Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Hangout History")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            LastHangoutRow(friend: friend)
                            Divider()
                            StatRow(title: "Total Time Together", value: getTotalHangoutTime())
                            Divider()
                            StatRow(title: "Mutual Connections", value: "\(getMutualConnections()) friends")
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                    
                    // Management Options Section
                    VStack(spacing: 0) {
                        ManagementRow(title: "Stop Sharing My Location", icon: "location.slash", color: .red)
                        Divider()
                        ManagementRow(title: "Remove \(friend.name)", icon: "trash", color: .red)
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getLocationString() -> String {
        if let location = friend.location {
            // Mock location names based on coordinates
            if location.latitude > 37.78 {
                return "San Francisco, CA"
            } else if location.latitude > 37.76 {
                return "Oakland, CA"
            } else {
                return "Berkeley, CA"
            }
        }
        return "Location unavailable"
    }
    
    private func getTotalHangoutTime() -> String {
        let hangouts = HangoutEngine.shared.getWeeklyHangouts()
        let friendHangouts = hangouts.filter { hangout in
            hangout.participants.contains { $0.id == friend.id }
        }
        
        let totalMinutes = friendHangouts.reduce(0) { total, hangout in
            total + Int(hangout.duration / 60) // Convert seconds to minutes
        }
        
        if totalMinutes < 60 {
            return "\(totalMinutes) minutes"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if minutes == 0 {
                return "\(hours) hours"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }
    
    private func getMutualConnections() -> Int {
        // Mock data - in real app, this would calculate actual mutual friends
        return Int.random(in: 3...8)
    }
}

struct LastHangoutRow: View {
    let friend: User
    
    init(friend: User) {
        self.friend = friend
    }
    
    var body: some View {
        let hangoutInfo = getLastHangoutInfo()
        
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Hangout")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(hangoutInfo.timeAgo)
                .font(.headline)
                .fontWeight(.medium)
            
            HStack(spacing: 8) {
                Text(hangoutInfo.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(hangoutInfo.duration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func getLastHangoutInfo() -> (timeAgo: String, location: String, duration: String) {
        let hangouts = HangoutEngine.shared.getWeeklyHangouts()
        let friendHangouts = hangouts.filter { hangout in
            hangout.participants.contains { $0.id == friend.id }
        }
        
        if let lastHangout = friendHangouts.max(by: { 
            let endTime1 = $0.endTime ?? $0.startTime
            let endTime2 = $1.endTime ?? $1.startTime
            return endTime1 < endTime2
        }) {
            let endTime = lastHangout.endTime ?? lastHangout.startTime
            let timeAgo = Date().timeIntervalSince(endTime)
            
            let timeAgoString: String
            if timeAgo < 3600 { // Less than 1 hour
                timeAgoString = "\(Int(timeAgo / 60)) minutes ago"
            } else if timeAgo < 86400 { // Less than 1 day
                timeAgoString = "\(Int(timeAgo / 3600)) hours ago"
            } else {
                timeAgoString = "\(Int(timeAgo / 86400)) days ago"
            }
            
            let locationString: String
            if let location = lastHangout.location {
                if location.latitude > 37.78 {
                    locationString = "Golden Gate Park"
                } else if location.latitude > 37.76 {
                    locationString = "Downtown Oakland"
                } else {
                    locationString = "UC Berkeley Campus"
                }
            } else {
                locationString = "Unknown location"
            }
            
            let durationMinutes = Int(lastHangout.duration / 60)
            let durationString: String
            if durationMinutes < 60 {
                durationString = "\(durationMinutes) minutes"
            } else {
                let hours = durationMinutes / 60
                let minutes = durationMinutes % 60
                if minutes == 0 {
                    durationString = "\(hours) hours"
                } else {
                    durationString = "\(hours)h \(minutes)m"
                }
            }
            
            return (timeAgoString, locationString, durationString)
        }
        
        return ("Never", "Unknown location", "0 minutes")
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct ManagementRow: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(color == .red ? .red : .primary)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            // Handle tap action
        }
    }
}

struct NoLocationPermissionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.slash")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Location Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Circle needs location access to show your friends on the map and detect hangouts. You can still use challenges and other features.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }) {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}


struct ContentView: View {
    @State private var selectedTab = 2
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Content area with swipe gesture
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    HomeView()
                        .frame(width: geometry.size.width)
                    
                    LeaderboardView()
                        .frame(width: geometry.size.width)
                    
                    CirclesView()
                        .frame(width: geometry.size.width)
            
            ChallengesView()
                        .frame(width: geometry.size.width)
                    
                    ProfileView()
                        .frame(width: geometry.size.width)
                }
                .offset(x: -CGFloat(selectedTab) * geometry.size.width + dragOffset)
                .animation(.interactiveSpring(), value: selectedTab)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            if value.translation.width < -threshold && selectedTab < 4 {
                                selectedTab += 1
                            } else if value.translation.width > threshold && selectedTab > 0 {
                                selectedTab -= 1
                            }
                            dragOffset = 0
                        }
                )
            }
            
            // Custom Tab Bar
            HStack(spacing: 0) {
                TabBarButton(icon: "house", selectedIcon: "house.fill", label: "Home", isSelected: selectedTab == 0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = 0
                    }
                }
                
                TabBarButton(icon: "trophy", selectedIcon: "trophy.fill", label: "Leaderboard", isSelected: selectedTab == 1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = 1
                    }
                }
                
                TabBarButton(icon: "circle.fill", selectedIcon: "circle.fill", label: "Circles", isSelected: selectedTab == 2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = 2
                    }
                }
                
                TabBarButton(icon: "target", selectedIcon: "target", label: "Challenges", isSelected: selectedTab == 3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = 3
                    }
                }
                
                TabBarButton(icon: "person", selectedIcon: "person.fill", label: "Profile", isSelected: selectedTab == 4) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = 4
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }
}

struct HomeView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Good morning")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Alex")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            // Profile Avatar - Minimalist
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }
                        
                        Text("Ready to prove it today?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    
                    // Quick Stats
                    HStack(spacing: 16) {
                        StatCard(title: "Points", value: "150", icon: "star.fill")
                        StatCard(title: "Challenges", value: "3", icon: "target")
                        StatCard(title: "Hangouts", value: "2", icon: "person.3.fill")
                    }
                    
                    // Active Challenges
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Challenges")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ChallengeCard(title: "Gym 4x this week", progress: 0.8)
                        ChallengeCard(title: "Walk 10k steps daily", progress: 0.7)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .navigationTitle("Circle")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
}

struct ChallengeCard: View {
    let title: String
    let progress: Double
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "figure.walk")
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                        .overlay(
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("2 days left")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Progress Indicator
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 2)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color(.systemGray4), lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
        )
    }
}

// Placeholder views for other tabs
struct CirclesView: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var hangoutEngine = HangoutEngine.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedFriend: User?
    @State private var circleMembers: [User] = []
    @State private var activeHangouts: [HangoutSession] = []
    @State private var weeklyHangouts: [HangoutSession] = []
    
    var body: some View {
        NavigationView {
            Group {
                if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                    // No location permission fallback
                    NoLocationPermissionView()
                } else {
                    // Main map view - ALWAYS show map with friends
                    ZStack {
                        // Custom MapKit Map View with proper overlays
                        CustomMapView(
                            region: $region,
                            circleMembers: circleMembers,
                            activeHangouts: activeHangouts,
                            weeklyHangouts: weeklyHangouts,
                            onFriendTap: { friend in
                                print("🎯 onFriendTap called for: \(friend.name)")
                                selectedFriend = friend
                            }
                        )
                        .onAppear {
                            setupLocationTracking()
                            loadCircleData()
                        }
                        
                        // Stats Overlay (screen overlay)
            VStack {
                            HStack {
                                Spacer()
                                StatsOverlayCard(
                                    activeHangouts: activeHangouts,
                                    weeklyHangouts: weeklyHangouts
                                )
                                .padding(.trailing, 16)
                            }
                            .padding(.top, 16)
                            
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Circles")
            .sheet(item: $selectedFriend) { friend in
                FriendDetailSheet(friend: friend)
                    .onAppear {
                        print("🎯 Sheet presenting for: \(friend.name)")
                    }
            }
        }
    }
    
    private func setupLocationTracking() {
        locationManager.requestLocationPermission()
        locationManager.startLocationUpdates { location in
            region.center = location.coordinate
        }
    }
    
    private func loadCircleData() {
        // Load ALL your friends - spread them out geographically like real friends would be
        circleMembers = [
            User(name: "You", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), profileEmoji: "👤"),
            User(name: "Sarah", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094), profileEmoji: "👩‍💼"), // North East
            User(name: "Mike", location: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294), profileEmoji: "👨‍💻"), // South West  
            User(name: "Josh", location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.3994), profileEmoji: "👨‍🎨"), // East
            User(name: "Emma", location: CLLocationCoordinate2D(latitude: 37.7949, longitude: -122.4194), profileEmoji: "👩‍🎓"), // North
            User(name: "Alex", location: CLLocationCoordinate2D(latitude: 37.7549, longitude: -122.4094), profileEmoji: "👨‍🍳"), // South East
            User(name: "Lisa", location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4394), profileEmoji: "👩‍⚕️") // North West
        ]
        
        // Load hangout data
        activeHangouts = hangoutEngine.getActiveHangouts()
        weeklyHangouts = hangoutEngine.getWeeklyHangouts()
    }
}

struct LeaderboardView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Leaderboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Weekly rankings will appear here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Leaderboard")
        }
    }
}

struct ChallengesView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Challenges")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Your challenges will appear here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Challenges")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Your profile will appear here")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Profile")
        }
    }
}

struct TabBarButton: View {
    let icon: String
    let selectedIcon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
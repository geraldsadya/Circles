//
//  DraggableBottomSheet.swift
//  Circle
//
//  Find My style draggable bottom sheet
//

import SwiftUI

struct DraggableBottomSheet<Content: View>: View {
    @Binding var isExpanded: Bool
    let content: Content
    
    // Sheet positions
    private let minHeight: CGFloat = 80  // Collapsed - just tab bar
    private let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.7  // Expanded
    
    @State private var currentHeight: CGFloat = 80
    @State private var dragOffset: CGFloat = 0
    
    init(isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isExpanded = isExpanded
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 8)
            
            // Content
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: currentHeight + dragOffset)
        .frame(maxWidth: .infinity)
        .background {
            // Find My style: more transparent material
            Rectangle()
                .fill(.thinMaterial)  // More transparent than ultraThin
        }
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : 20))
        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        .offset(y: UIScreen.main.bounds.height - currentHeight - dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = -value.translation.height
                }
                .onEnded { value in
                    let velocity = value.predictedEndLocation.y - value.location.y
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if dragOffset > 100 || velocity < -200 {
                            // Expand
                            currentHeight = maxHeight
                            isExpanded = true
                        } else if dragOffset < -50 || velocity > 200 {
                            // Collapse
                            currentHeight = minHeight
                            isExpanded = false
                        } else {
                            // Snap back to current state
                            currentHeight = isExpanded ? maxHeight : minHeight
                        }
                        
                        dragOffset = 0
                    }
                }
        )
        .onChange(of: isExpanded) { newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentHeight = newValue ? maxHeight : minHeight
            }
        }
    }
}

// MARK: - Find My Style Bottom Sheet with Tabs
struct FindMyStyleBottomSheet: View {
    @Binding var selectedTab: Int
    @Binding var isExpanded: Bool
    
    @State private var dragOffset: CGFloat = 0
    
    // Sheet heights
    private let collapsedHeight: CGFloat = 80
    private var expandedHeight: CGFloat {
        UIScreen.main.bounds.height * 0.65
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            dragHandle
            
            // Tab bar (always visible)
            tabBar
            
            // Expandable content (only when expanded)
            if isExpanded {
                Divider()
                    .padding(.top, 8)
                
                ScrollView {
                    expandedContent
                        .padding(.top, 12)
                }
                .frame(height: expandedHeight - collapsedHeight - 30)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isExpanded ? expandedHeight : collapsedHeight)
        .background {
            // Find My style: thin material for maximum transparency with blur
            Rectangle()
                .fill(.thinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow dragging up when collapsed, down when expanded
                    let translation = value.translation.height
                    
                    if isExpanded && translation > 0 {
                        // Dragging down when expanded
                        dragOffset = translation
                    } else if !isExpanded && translation < 0 {
                        // Dragging up when collapsed
                        dragOffset = translation
                    }
                }
                .onEnded { value in
                    let velocity = value.predictedEndTranslation.height
                    let threshold: CGFloat = 80
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if !isExpanded && (dragOffset < -threshold || velocity < -200) {
                            // Expand
                            isExpanded = true
                        } else if isExpanded && (dragOffset > threshold || velocity > 200) {
                            // Collapse
                            isExpanded = false
                        }
                        
                        dragOffset = 0
                    }
                }
        )
    }
    
    // MARK: - Drag Handle (Find My style)
    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color(.systemGray3))
            .frame(width: 36, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 6)
    }
    
    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house",
                selectedIcon: "house.fill",
                label: "Home",
                isSelected: selectedTab == 0
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = 0
                    isExpanded = true
                }
            }
            
            TabBarButton(
                icon: "circle.fill",
                selectedIcon: "circle.fill",
                label: "Circles",
                isSelected: selectedTab == 1
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = 1
                    isExpanded = false  // Circles tab doesn't expand
                }
            }
            
            TabBarButton(
                icon: "target",
                selectedIcon: "target",
                label: "Circles",
                isSelected: selectedTab == 2
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = 2
                    isExpanded = true
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }
    
    // MARK: - Expanded Content
    @ViewBuilder
    private var expandedContent: some View {
        switch selectedTab {
        case 0:
            // Home content
            HomeSheetContent()
        case 2:
            // Challenges content
            ChallengesSheetContent()
        default:
            EmptyView()
        }
    }
}

// MARK: - Home Sheet Content
struct HomeSheetContent: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var motionManager = MotionManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // Welcome header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good \(timeOfDay)")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text(UIDevice.current.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Health Stats
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                
                HStack(spacing: 16) {
                    HealthStatCard(
                        title: "Steps",
                        value: "\(healthKitManager.todaysSteps)",
                        icon: "figure.walk",
                        color: .green
                    )
                    
                    HealthStatCard(
                        title: "Sleep",
                        value: String(format: "%.1fh", healthKitManager.todaysSleepHours)",
                        icon: "bed.double",
                        color: .purple
                    )
                    
                    HealthStatCard(
                        title: "Hangouts",
                        value: "2",
                        icon: "person.2.fill",
                        color: .blue
                    )
                }
                .padding(.horizontal, 20)
            }
            
            // Active Challenges Preview
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Active Challenges")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("View All") {
                        // Navigate to challenges
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 20)
                
                // Mock challenge cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<3) { i in
                            CompactChallengeCard(
                                title: "Challenge \(i + 1)",
                                icon: "figure.walk",
                                progress: 0.7
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
    
    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }
}

// MARK: - Compact Challenge Card
struct CompactChallengeCard: View {
    let title: String
    let icon: String
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: progress)
                .tint(.blue)
            
            Text("\(Int(progress * 100))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(width: 160)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Challenges Sheet Content
struct ChallengesSheetContent: View {
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Challenges")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Compete with friends")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    // Create new challenge
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            
            // Challenge categories
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CategoryPill(title: "All", isSelected: true)
                    CategoryPill(title: "Fitness", isSelected: false)
                    CategoryPill(title: "Social", isSelected: false)
                    CategoryPill(title: "Sleep", isSelected: false)
                }
                .padding(.horizontal, 20)
            }
            
            // Challenge list
            VStack(spacing: 12) {
                ForEach(0..<2) { i in
                    ChallengeListRow(
                        title: "Daily Steps",
                        subtitle: "Walk 10,000 steps",
                        participants: 4,
                        progress: 0.65
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .clipShape(Capsule())
    }
}

// MARK: - Challenge List Row
struct ChallengeListRow: View {
    let title: String
    let subtitle: String
    let participants: Int
    let progress: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(participants) people")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            CircularProgressView(progress: progress)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Circular Progress
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 3)
                .frame(width: 36, height: 36)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, lineWidth: 3)
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))")
                .font(.caption2)
                .fontWeight(.bold)
        }
    }
}

// MARK: - Health Stat Card (for sheet content)
struct HealthStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
                Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Placeholder HealthKitManager for compilation
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    @Published var todaysSteps: Int = 0
    @Published var todaysSleepHours: Double = 0.0
    private init() {}
}

class MotionManager: ObservableObject {
    static let shared = MotionManager()
    private init() {}
}

#Preview {
    ZStack {
        Color.blue.opacity(0.3).ignoresSafeArea()
        
        FindMyStyleBottomSheet(
            selectedTab: .constant(0),
            isExpanded: .constant(false)
        )
    }
}


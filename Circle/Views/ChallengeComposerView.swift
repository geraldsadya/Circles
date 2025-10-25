//
//  ChallengeComposerView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import CoreData
import CoreLocation

struct ChallengeComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var challengeTemplateManager = ChallengeTemplateManager.shared
    
    @State private var selectedTemplate: ChallengeTemplate?
    @State private var challengeTitle = ""
    @State private var challengeDescription = ""
    @State private var selectedCategory: ChallengeCategory = .fitness
    @State private var selectedCircle: Circle?
    @State private var targetValue: Double = 1000
    @State private var targetUnit = "steps"
    @State private var frequency: ChallengeFrequency = .daily
    @State private var verificationMethod: VerificationMethod = .motion
    @State private var pointsReward = 10
    @State private var pointsPenalty = -5
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var showingLocationPicker = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationRadius: Double = 75
    @State private var minDuration: Double = 20
    @State private var isCreating = false
    @State private var validationErrors: [String] = []
    
    var body: some View {
        NavigationView {
            Form {
                // Template Selection
                templateSection
                
                // Basic Info
                basicInfoSection
                
                // Challenge Parameters
                parametersSection
                
                // Verification Method
                verificationSection
                
                // Circle Selection
                circleSection
                
                // Schedule
                scheduleSection
                
                // Points
                pointsSection
                
                // Validation Errors
                if !validationErrors.isEmpty {
                    validationSection
                }
            }
            .navigationTitle("Create Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createChallenge()
                    }
                    .disabled(!isValidChallenge || isCreating)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
            }
        }
        .onAppear {
            loadTemplates()
            loadCircles()
        }
    }
    
    // MARK: - Template Section
    private var templateSection: some View {
        Section {
            if !presetTemplates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(presetTemplates, id: \.id) { template in
                            TemplateCard(
                                template: template,
                                isSelected: selectedTemplate?.id == template.id
                            ) {
                                selectTemplate(template)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        } header: {
            Text("Choose Template")
        } footer: {
            Text("Start with a preset or create a custom challenge")
        }
    }
    
    // MARK: - Basic Info Section
    private var basicInfoSection: some View {
        Section {
            TextField("Challenge Title", text: $challengeTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Description (Optional)", text: $challengeDescription, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
            
            Picker("Category", selection: $selectedCategory) {
                ForEach(ChallengeCategory.allCases, id: \.self) { category in
                    HStack {
                        Image(systemName: category.icon)
                        Text(category.displayName)
                    }
                    .tag(category)
                }
            }
            .pickerStyle(MenuPickerStyle())
        } header: {
            Text("Basic Information")
        }
    }
    
    // MARK: - Parameters Section
    private var parametersSection: some View {
        Section {
            HStack {
                Text("Target")
                Spacer()
                TextField("Value", value: $targetValue, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                
                TextField("Unit", text: $targetUnit)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
            
            Picker("Frequency", selection: $frequency) {
                ForEach(ChallengeFrequency.allCases, id: \.self) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        } header: {
            Text("Challenge Parameters")
        }
    }
    
    // MARK: - Verification Section
    private var verificationSection: some View {
        Section {
            Picker("Verification Method", selection: $verificationMethod) {
                ForEach(VerificationMethod.allCases, id: \.self) { method in
                    HStack {
                        Image(systemName: method.icon)
                        Text(method.displayName)
                    }
                    .tag(method)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            if verificationMethod == .location {
                locationVerificationFields
            } else if verificationMethod == .motion {
                motionVerificationFields
            }
        } header: {
            Text("Verification")
        }
    }
    
    // MARK: - Location Verification Fields
    private var locationVerificationFields: some View {
        VStack(spacing: 12) {
            Button(action: { showingLocationPicker = true }) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    
                    if let location = selectedLocation {
                        Text("Location Selected")
                            .foregroundColor(.primary)
                    } else {
                        Text("Select Location")
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            if selectedLocation != nil {
                HStack {
                    Text("Radius")
                    Spacer()
                    TextField("Radius", value: $locationRadius, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                    Text("meters")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Min Duration")
                    Spacer()
                    TextField("Duration", value: $minDuration, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                    Text("minutes")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Motion Verification Fields
    private var motionVerificationFields: some View {
        VStack(spacing: 12) {
            Text("Motion verification will track your steps and activity automatically.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Circle Section
    private var circleSection: some View {
        Section {
            Picker("Circle", selection: $selectedCircle) {
                Text("Personal").tag(nil as Circle?)
                ForEach(userCircles, id: \.id) { circle in
                    Text(circle.name ?? "Untitled").tag(circle as Circle?)
                }
            }
            .pickerStyle(MenuPickerStyle())
        } header: {
            Text("Circle")
        } footer: {
            Text("Choose a circle to share this challenge with friends")
        }
    }
    
    // MARK: - Schedule Section
    private var scheduleSection: some View {
        Section {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
        } header: {
            Text("Schedule")
        }
    }
    
    // MARK: - Points Section
    private var pointsSection: some View {
        Section {
            HStack {
                Text("Reward")
                Spacer()
                TextField("Points", value: $pointsReward, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
            }
            
            HStack {
                Text("Penalty")
                Spacer()
                TextField("Points", value: $pointsPenalty, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
            }
        } header: {
            Text("Points")
        } footer: {
            Text("Points earned for completing or missing the challenge")
        }
    }
    
    // MARK: - Validation Section
    private var validationSection: some View {
        Section {
            ForEach(validationErrors, id: \.self) { error in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.primary)
                }
            }
        } header: {
            Text("Issues to Fix")
        }
    }
    
    // MARK: - Computed Properties
    private var presetTemplates: [ChallengeTemplate] {
        challengeTemplateManager.presetTemplates()
    }
    
    private var userCircles: [Circle] {
        let request: NSFetchRequest<Circle> = Circle.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching circles: \(error)")
            return []
        }
    }
    
    private var isValidChallenge: Bool {
        validationErrors = []
        
        if challengeTitle.isEmpty {
            validationErrors.append("Challenge title is required")
        }
        
        if targetValue <= 0 {
            validationErrors.append("Target value must be greater than 0")
        }
        
        if targetUnit.isEmpty {
            validationErrors.append("Target unit is required")
        }
        
        if verificationMethod == .location && selectedLocation == nil {
            validationErrors.append("Location must be selected for location verification")
        }
        
        if locationRadius < 25 {
            validationErrors.append("Location radius must be at least 25 meters")
        }
        
        if minDuration < 5 {
            validationErrors.append("Minimum duration must be at least 5 minutes")
        }
        
        if startDate >= endDate {
            validationErrors.append("End date must be after start date")
        }
        
        return validationErrors.isEmpty
    }
    
    // MARK: - Methods
    private func loadTemplates() {
        challengeTemplateManager.loadTemplates()
    }
    
    private func loadCircles() {
        // Circles are loaded in computed property
    }
    
    private func selectTemplate(_ template: ChallengeTemplate) {
        selectedTemplate = template
        challengeTitle = template.title ?? ""
        challengeDescription = template.descriptionText ?? ""
        selectedCategory = ChallengeCategory(rawValue: template.category ?? "fitness") ?? .fitness
        targetValue = template.targetValue
        targetUnit = template.targetUnit ?? "steps"
        verificationMethod = VerificationMethod(rawValue: template.verificationMethod ?? "motion") ?? .motion
    }
    
    private func createChallenge() {
        guard isValidChallenge else { return }
        
        isCreating = true
        
        // Create challenge in Core Data
        let newChallenge = Challenge.create(
            in: viewContext,
            title: challengeTitle,
            category: selectedCategory.rawValue,
            verificationMethod: verificationMethod.rawValue
        )
        
        newChallenge.descriptionText = challengeDescription.isEmpty ? nil : challengeDescription
        newChallenge.targetValue = targetValue
        newChallenge.targetUnit = targetUnit
        newChallenge.frequency = frequency.rawValue
        newChallenge.pointsReward = Int32(pointsReward)
        newChallenge.pointsPenalty = Int32(pointsPenalty)
        newChallenge.startDate = startDate
        newChallenge.endDate = endDate
        newChallenge.circle = selectedCircle
        newChallenge.createdBy = authManager.currentUser
        
        // Set verification parameters
        if verificationMethod == .location, let location = selectedLocation {
            let params = LocationChallengeParams(
                targetLocation: location,
                radiusMeters: locationRadius,
                minDurationMinutes: minDuration,
                name: challengeTitle
            )
            
            if let data = try? JSONEncoder().encode(params) {
                newChallenge.verificationParams = data
            }
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error creating challenge: \(error)")
            isCreating = false
        }
    }
}

// MARK: - Template Card
struct TemplateCard: View {
    let template: ChallengeTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: templateIcon)
                        .font(.title2)
                        .foregroundColor(templateColor)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                
                Text(template.title ?? "Untitled")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(template.descriptionText ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("\(Int(template.targetValue)) \(template.targetUnit ?? "")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text(template.verificationMethod?.capitalized ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(width: 160, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var templateIcon: String {
        switch template.category {
        case "fitness": return "figure.walk"
        case "screen_time": return "iphone"
        case "sleep": return "moon.fill"
        case "social": return "person.3.fill"
        default: return "target"
        }
    }
    
    private var templateColor: Color {
        switch template.category {
        case "fitness": return .green
        case "screen_time": return .orange
        case "sleep": return .purple
        case "social": return .blue
        default: return .gray
        }
    }
}

// MARK: - Location Picker View
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Location Picker")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Location picker implementation coming soon...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Set a default location for now
                        selectedLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ChallengeComposerView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AuthenticationManager.shared)
}
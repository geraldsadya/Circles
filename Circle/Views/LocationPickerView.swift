//
//  LocationPickerView.swift
//  Circle
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var locationName: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedAnnotation: LocationAnnotation?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchSection
                
                // Map
                mapSection
                
                // Location Details
                if let location = selectedLocation {
                    locationDetailsSection(location: location)
                }
            }
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
                        if let location = selectedLocation {
                            // Reverse geocode to get location name if not provided
                            if locationName.isEmpty {
                                reverseGeocode(location: location)
                            }
                        }
                        dismiss()
                    }
                    .disabled(selectedLocation == nil)
                }
            }
        }
        .onAppear {
            setupInitialLocation()
        }
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search for a location", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        searchForLocation()
                    }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Search Results
            if !searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults, id: \.self) { item in
                            SearchResultRow(item: item) {
                                selectSearchResult(item)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Map Section
    private var mapSection: some View {
        Map(coordinateRegion: $region, annotationItems: selectedAnnotation != nil ? [selectedAnnotation!] : []) { annotation in
            MapPin(coordinate: annotation.coordinate, tint: .blue)
        }
        .onTapGesture { location in
            let coordinate = region.center
            selectLocation(coordinate: coordinate)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Convert drag to coordinate
                    let coordinate = region.center
                    selectLocation(coordinate: coordinate)
                }
        )
    }
    
    // MARK: - Location Details Section
    private func locationDetailsSection(location: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Location")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    
                    Text("Coordinates")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Text("\(location.latitude, specifier: "%.6f"), \(location.longitude, specifier: "%.6f")")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fontFamily(.monospaced)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.cursor")
                        .foregroundColor(.blue)
                    
                    Text("Location Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                TextField("Enter location name", text: $locationName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "scope")
                        .foregroundColor(.blue)
                    
                    Text("Detection Radius")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Text("\(Int(Verify.geofenceRadius)) meters")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - Helper Methods
    private func setupInitialLocation() {
        // Try to get user's current location
        let locationManager = CLLocationManager()
        
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {
            
            if let currentLocation = locationManager.location {
                region.center = currentLocation.coordinate
                selectLocation(coordinate: currentLocation.coordinate)
            }
        }
    }
    
    private func searchForLocation() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    return
                }
                
                searchResults = response?.mapItems ?? []
            }
        }
    }
    
    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        region.center = coordinate
        
        // Update region span for better view
        region.span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        
        selectLocation(coordinate: coordinate)
        
        // Set location name from search result
        if let name = item.name {
            locationName = name
        }
        
        // Clear search results
        searchResults = []
        searchText = ""
    }
    
    private func selectLocation(coordinate: CLLocationCoordinate2D) {
        selectedLocation = coordinate
        
        // Create annotation
        selectedAnnotation = LocationAnnotation(
            id: UUID(),
            coordinate: coordinate,
            title: locationName.isEmpty ? "Selected Location" : locationName
        )
        
        // Update region to center on selected location
        region.center = coordinate
        region.span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    }
    
    private func reverseGeocode(location: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Reverse geocoding error: \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first {
                    var nameComponents: [String] = []
                    
                    if let name = placemark.name {
                        nameComponents.append(name)
                    }
                    
                    if let locality = placemark.locality {
                        nameComponents.append(locality)
                    }
                    
                    if let administrativeArea = placemark.administrativeArea {
                        nameComponents.append(administrativeArea)
                    }
                    
                    locationName = nameComponents.joined(separator: ", ")
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct SearchResultRow: View {
    let item: MKMapItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name ?? "Unknown Location")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let address = item.placemark.title {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Supporting Types
struct LocationAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String
}

#Preview {
    LocationPickerView(
        selectedLocation: .constant(CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)),
        locationName: .constant("San Francisco")
    )
}

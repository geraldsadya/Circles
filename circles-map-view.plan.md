<!-- 3625bd16-a368-450a-8e9b-d2c10fcf0cb2 0581f7a3-581b-43cc-899e-0b5de33b5fb5 -->
# Circles Map View Implementation

## Overview

Transform the Circles page from a placeholder into an interactive map view (like Find My) that displays circle members' locations, connection lines showing hangout relationships, and tracks time spent together.

## Current State

- Circles page shows placeholder text: "Your friend groups will appear here"
- Located in `Circle/ContentView.swift` as `CirclesView`
- No map functionality implemented yet

## Implementation Plan

### 1. Map View Foundation

**File:** `Circle/Views/CirclesView.swift` (replace current placeholder)

Replace the placeholder `CirclesView` with:

- MapKit integration using `MKMapView` or SwiftUI `Map`
- Center map on current user's location
- Show user's location as a blue dot (standard MapKit)
- Display circle members as custom annotations (profile pictures/avatars)

### 2. Location Service Integration

**Files:**

- Use existing `Circle/Services/LocationManager.swift`
- Verify background location tracking is enabled

Requirements:

- Request "Always" location permission (already in app flow)
- Use Significant Location Change (SLC) for battery efficiency
- Store last known location for each user
- Update locations when app opens and periodically in background

### 3. Connection Lines (Hangout Visualization)

**Logic:**

- Draw lines between circle members based on hangout data
- Line types:
  - **Solid bright line**: Currently hanging out (within 10m, active session)
  - **Dashed line**: Hung out recently this week
  - **No line**: Haven't hung out yet
- Line thickness: Proportional to total hangout time this week
- Use `MKPolyline` or SwiftUI `MapPolyline` to render lines

### 4. Hangout Detection Integration

**Files:**

- Use existing `Circle/Services/HangoutEngine.swift` (from docs)
- Query active and recent hangout sessions
- Filter by current week for "recent" status

Data needed:

- Active hangouts: Friends currently within 10m for 5+ minutes
- Weekly hangouts: All completed hangout sessions from current week
- Total time per friend pair

### 5. Interactive Features

When user taps a friend on the map:

- Show bottom sheet/modal with:
  - Friend's name and profile
  - Total hangout time this week
  - Recent hangout locations
  - Active challenges with them
  - Option to send new challenge
  - Hangout history

### 6. Stats Overlay

**Component:** Floating info card at top or bottom of map

Display:

- Current active hangouts: "Currently with Sarah and Mike"
- Weekly summary: "12 hours with friends this week"
- Top hangout buddy: "Most time with Sarah (8 hours)"

### 7. Data Models Required

Ensure these models exist (from Technical Handoff):

- `User`: with location data
- `HangoutSession`: with participants, duration, location
- `Circle`: with members list

### 8. Edge Cases to Handle

- No location permission: Show list view fallback
- No circle members yet: Show "Invite friends" onboarding
- Single user in circle: Show map with just user location
- All friends' locations stale: Show last known with timestamp

## Files to Modify

1. **`Circle/Views/CirclesView.swift`**

   - Replace entire placeholder implementation
   - Add MapKit map view
   - Implement custom annotations for users
   - Draw connection lines between users
   - Add stats overlay component

2. **`Circle/Services/LocationManager.swift`**

   - Verify background tracking
   - Add method to fetch all circle members' locations
   - Handle location updates

3. **`Circle/Services/HangoutEngine.swift`**

   - Add query methods for active hangouts
   - Add query methods for weekly hangout data
   - Calculate total time per friend pair

4. **Create new file: `Circle/Views/Components/CircleMemberAnnotation.swift`**

   - Custom map annotation view
   - Display profile picture/avatar
   - Handle selection state

5. **Create new file: `Circle/Views/Components/FriendDetailSheet.swift`**

   - Bottom sheet shown when tapping a friend
   - Show hangout stats and options

## Technical Details

### MapKit Setup

```swift
import MapKit
import SwiftUI

struct CirclesMapView: View {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var hangoutEngine = HangoutEngine.shared
    @State private var region = MKCoordinateRegion(...)
    @State private var selectedFriend: User?
    
    var body: some View {
        Map(coordinateRegion: $region, 
            showsUserLocation: true,
            annotationItems: circleMembers) { member in
            // Custom annotation
        }
        .overlay {
            // Stats overlay
            // Connection lines
        }
        .sheet(item: $selectedFriend) { friend in
            FriendDetailSheet(friend: friend)
        }
    }
}
```

### Connection Lines Logic

- Query `HangoutSession` for current week
- Group by participant pairs
- Calculate line properties based on data
- Render using `MKPolyline` overlay

## Success Criteria

- [x] Map displays user's current location
- [x] Circle members appear as custom annotations with profile pictures
- [x] Connection lines show hangout relationships
- [x] Active hangouts display with solid lines
- [x] Recent hangouts display with dashed lines
- [x] Line thickness reflects total hangout time
- [x] Tapping a friend shows detail sheet
- [x] Stats overlay shows current and weekly summary
- [x] Handles no permissions gracefully with fallback
- [x] Background location tracking works as expected

## Future Enhancements (Not in Initial Implementation)

- Zoom to show all circle members
- Filter by specific friend
- Show historical hangout heatmap
- Animate connection lines
- Show challenge markers on map

### Collaborative Photo Stories Feature

**Concept:** Consent-based photo sharing system tied to hangout sessions

**Core Features:**
- **Tagged Photos Only** - Users can only post pictures with someone else tagged
- **Consent Required** - Tagged person must accept the tag before photo goes live
- **Story Format** - Tap friend's profile → see their "story" of accepted photos
- **Hangout Context** - Photos are tied to actual hangout sessions and locations

**User Experience:**
- **Photo Capture** - Take photo during hangout, tag friends who are present
- **Tag Approval** - Friends get notification to approve/decline being tagged
- **Story View** - Tap friend's map icon → see their photo story timeline
- **Location Integration** - Photos show where hangout happened on map

**Privacy & Consent:**
- **Granular Control** - Friends can approve individual photos or set auto-approve
- **Tag Removal** - Can remove tags from photos they're in
- **Story Privacy** - Control who can see their photo story

**Visual Design:**
- **Instagram Stories-style** interface within friend detail sheet
- **Map Integration** - Photos appear as pins on hangout locations
- **Timeline View** - Chronological story of accepted photos
- **Hangout Context** - Each photo shows hangout duration and participants

**Cool Extensions:**
- **Group Stories** - Photos from group hangouts appear in everyone's story
- **Memory Highlights** - Best photos from hangouts get special treatment
- **Location Stories** - See all photos taken at specific hangout spots
- **Weekly Recap** - Auto-generated story of the week's best moments

### To-dos

- [x] Replace CirclesView placeholder with MapKit integration showing user location
- [x] Create custom map annotations for circle members with profile pictures
- [x] Draw connection lines between members based on hangout data (solid for active, dashed for recent)
- [x] Query HangoutEngine for active and weekly hangout sessions to drive connection visualization
- [x] Create floating stats card showing current hangouts and weekly summary
- [x] Implement bottom sheet that appears when tapping a friend, showing hangout history and actions
- [x] Add fallback views for no permissions, no members, and stale location data
- [ ] **Health App Integration**: Research and implement HealthKit integration for steps leaderboard
  - Import daily step count data from Health app
  - Create weekly/monthly steps leaderboard among circle members
  - Handle HealthKit permissions and privacy
  - Sync step data across friend groups for competitive leaderboards
- [ ] Add collaborative photo stories feature to ideas list

# Testing Circle App with 2 iPhones

## Current Status

Right now, the app uses **mock data** for testing the UI. This means:
- ✅ UI works and looks good
- ✅ Map shows your location
- ✅ Mock friends appear around you
- ❌ Real-time data sharing between devices NOT yet implemented
- ❌ Friends can't actually see each other yet
- ❌ Challenges and hangouts are simulated, not real

## Quick Fix - See Mock Friends on Real Device

The mock friends now appear **relative to your location** instead of hardcoded to San Francisco. When you open the Circles tab:
1. Grant location permissions
2. Wait 1-2 seconds for location to load
3. You should see 6 mock friends (Sarah, Mike, Josh, Emma, Alex, Lisa) spread around you within ~1-2km

Check Xcode console for logs:
```
🗺️ Loading circle data at location: [your lat], [your lon]
📍 Created 7 circle members around user location
```

## Installing on Both iPhones

### Option 1: Using Same Apple Developer Account
1. Connect iPhone 1 to Mac
2. Select iPhone 1 as target in Xcode
3. Click Run (⌘R)
4. Once installed, disconnect iPhone 1
5. Connect iPhone 2
6. Select iPhone 2 as target
7. Click Run (⌘R)

### Option 2: Using Different Apple IDs
- Each iPhone needs to be signed in with a different Apple ID in Xcode
- Go to Xcode > Preferences > Accounts
- Add both Apple IDs
- Switch between them when building for each device

## What Works Now (Mock Data)

On each device independently:
- ✅ See your location on map
- ✅ See 6 mock friends around you
- ✅ Tap friends to see detail sheets
- ✅ See connection lines between friends
- ✅ View challenges (all simulated)
- ✅ See health stats (if HealthKit authorized)

## What Doesn't Work Yet (Needs Implementation)

### For Real 2-Device Testing, You Need:

#### 1. **Real Authentication & User Creation**
```swift
// Need to implement:
- Sign in with Apple on both devices
- Create unique user profiles in CloudKit
- Store user data (name, emoji, etc.)
```

#### 2. **CloudKit Sharing & Sync**
```swift
// Need to implement:
- Share location in real-time via CloudKit
- Friend invite/accept system
- Sync hangout sessions between users
- Sync challenges and progress
```

#### 3. **Location Sharing**
```swift
// Need to implement:
- Background location updates
- Upload location to CloudKit every X seconds
- Fetch friends' locations from CloudKit
- Real-time proximity detection
```

#### 4. **Friend Connections**
```swift
// Need to implement:
- Generate and share invite codes
- Add friends by code or contact
- Store friend relationships in CloudKit
- Query and display actual friends on map
```

## Steps to Enable Real Testing

### Phase 1: Basic Data Sync (Next Steps)

1. **Enable iCloud in Xcode**
   - Select project → Signing & Capabilities
   - Add "iCloud" capability
   - Enable "CloudKit"
   - Create CloudKit container: `iCloud.com.yourteam.circle`

2. **Enable Background Modes**
   - Add "Background Modes" capability
   - Enable "Location updates"
   - Enable "Background fetch"
   - Enable "Remote notifications"

3. **Test on Both Devices**
   - Sign in with DIFFERENT Apple IDs on each device
   - Both should be signed into iCloud
   - Grant all permissions on both devices

### Phase 2: Implement Core Features

1. **Authentication Flow**
   ```swift
   // On first launch:
   - Sign in with Apple
   - Create user profile
   - Upload to CloudKit
   ```

2. **Friend System**
   ```swift
   // Add friends:
   - Generate unique invite code
   - Share code (QR, text, etc.)
   - Other user enters code
   - Create friend relationship in CloudKit
   ```

3. **Location Sharing**
   ```swift
   // Continuous updates:
   - Get user location every 30 seconds
   - Upload to CloudKit
   - Fetch friends' locations
   - Update map markers
   ```

4. **Real-Time Updates**
   ```swift
   // Push notifications:
   - Set up CloudKit subscriptions
   - Receive updates when friends move
   - Update UI automatically
   ```

## Current Testing Workflow

### What You Can Test Now:

1. **UI/UX Testing**
   - Navigation between tabs
   - Map interactions
   - Animations and transitions
   - Permission flows

2. **Location Accuracy**
   - Does your location show correctly?
   - Do mock friends appear around you?
   - Are distances reasonable?

3. **Performance**
   - Battery usage during location tracking
   - App responsiveness
   - Memory usage

### What to Check in Console:

```
🗺️ Loading circle data at location: [coordinates]
📍 Created 7 circle members around user location
👥 Active hangouts: 2, Weekly hangouts: 4
✅ HealthKit is available on this device
🔐 HealthKit authorized: true
```

## Next Development Tasks

To enable real 2-device testing:

### High Priority:
1. ✅ Fix mock friends to show relative to user location (DONE)
2. ⬜ Implement CloudKit user creation
3. ⬜ Implement friend invite/accept system
4. ⬜ Implement real-time location sharing
5. ⬜ Test with 2 devices signed in with different Apple IDs

### Medium Priority:
6. ⬜ Implement challenge creation/acceptance
7. ⬜ Implement proximity-based hangout detection
8. ⬜ Add push notifications for friend updates

### Low Priority:
9. ⬜ Photo stories feature
10. ⬜ Circle wrapped analytics

## Troubleshooting

### Friends Don't Appear on Map

**Check:**
1. Location permission granted?
2. Wait 1-2 seconds after opening Circles tab
3. Check Xcode console for "Loading circle data" log
4. Try zooming out on the map

### App Crashes on Real Device

**Common Issues:**
1. HealthKit entitlements not set up
2. CloudKit container not created
3. Missing Info.plist permissions
4. Provisioning profile issues

### Different Behavior on Device vs Simulator

**Normal Differences:**
- HealthKit doesn't work in simulator
- Location is more accurate on device
- Performance is different
- Mock data loads the same way

## Contact & Support

For questions or issues:
1. Check console logs in Xcode
2. Review CIRCLE_CONTEXT.md for architecture
3. Check CloudKit dashboard for data sync issues

---

**TL;DR for Testing Now:**
- Both devices will show the same mock friends around their own location
- They won't actually see each other yet - that needs CloudKit implementation
- Use this time to test UI, performance, and user experience
- Real multi-device testing requires implementing authentication and CloudKit sharing (next phase)


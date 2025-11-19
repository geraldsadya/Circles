# Quick Start - Test with 2 iPhones NOW!

## ⚡️ Super Fast Setup (5 minutes)

### Before You Run the App:

1. **Xcode Setup** (2 minutes):
   - Open project in Xcode
   - Select Circle target → Signing & Capabilities
   - Add **iCloud** capability → Check CloudKit → Add container: `iCloud.com.circle.app`
   - Add **Background Modes** → Check: Location updates, Background fetch, Remote notifications
   - Add **Sign in with Apple** capability

2. **Info.plist** (1 minute):
   - Open Info.plist
   - Add these 3 location permission strings:
     - `NSLocationAlwaysAndWhenInUseUsageDescription`
     - `NSLocationWhenInUseUsageDescription` 
     - `NSLocationAlwaysUsageDescription`
   - Value: "Circle needs your location to show friends and detect hangouts"

### Testing Flow:

#### iPhone 1:
1. Run app → Sign in with Apple (Apple ID #1)
2. Create profile (name + emoji)
3. Allow location → **Choose "Always"**
4. Go to Circles tab → Tap + icon (top right)
5. Tap "Generate Invite Code"
6. **Write down the 6-letter code!**

#### iPhone 2:
1. Run app → Sign in with Apple (Apple ID #2 - MUST BE DIFFERENT)
2. Create profile (different name + emoji)
3. Allow location → **Choose "Always"**
4. Go to Circles tab → Tap + icon (top right)
5. Enter iPhone 1's invite code
6. Tap "Add Friend"

#### Wait 15-30 seconds...

**🎉 You should now see each other on the map!**

## ✅ What Works:
- Sign in with Apple on each device
- Generate and share invite codes
- Add friends with codes
- Real-time location sharing (updates every 15 sec)
- See friends on map with emojis
- Background location updates
- Works even when app is closed

## 🔍 Quick Debug:

**Can't see friend?**
- Check: Different Apple IDs? ✓
- Check: Location set to "Always"? ✓
- Check: Internet connection? ✓
- Check: Xcode console for errors

**Console should show:**
```
✅ User profile created in CloudKit
📍 Location sharing started
✅ Friend added successfully
📱 Loading REAL friends from CloudKit
✅ Added friend: [name] at [coordinates]
```

## 🚀 That's It!

Once you see each other:
- Walk around → Watch locations update
- Test background mode → Close app, move, reopen
- Add more friends → Generate more codes!

**Full guide with troubleshooting**: See `REAL_DEVICE_SETUP.md`


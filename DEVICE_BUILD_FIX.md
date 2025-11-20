# Device Build Not Showing Changes - Fix

## Problem

Changes show in Simulator but not on real iPhone device.

## Solution

### Quick Fix (Try This First):

1. **Clean Build Folder in Xcode**
   ```
   Shift + Command + K (Clean Build Folder)
   ```

2. **Delete App from iPhone**
   - Long press Circle app on iPhone
   - Delete it completely

3. **Rebuild Fresh**
   ```
   Command + B (Build)
   Command + R (Run)
   ```

### If That Doesn't Work:

1. **Close Xcode Completely**

2. **Navigate to Project Directory**
   ```bash
   cd /Users/joshuanehohwa/Documents/Circles
   ```

3. **Pull Latest Changes**
   ```bash
   git pull origin main
   ```

4. **Clean Derived Data**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Circle-*
   ```

5. **Reopen Project**
   ```bash
   open Circle.xcodeproj
   ```

6. **Clean + Build**
   - Shift + Command + K (Clean)
   - Command + B (Build)
   - Select your iPhone as target
   - Command + R (Run)

### Check Xcode Settings:

1. **Select Your iPhone** in device dropdown (not simulator)
2. **Product → Scheme → Circle** should be selected
3. **Product → Destination → Your iPhone** should be selected
4. **Build Configuration**: Should be "Debug" for testing

### Nuclear Option (If Nothing Works):

1. **Delete Xcode Derived Data Completely**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/*
   ```

2. **Delete App from iPhone**

3. **Restart Xcode**

4. **Rebuild Everything**
   - Clean Build Folder (Shift + Cmd + K)
   - Build (Cmd + B)
   - Run on Device (Cmd + R)

## Verification

After rebuilding, you should see:

✅ **Draggable pill** at bottom with small gray handle bar  
✅ **Can swipe UP** to expand  
✅ **Map blurs** when expanded  
✅ **Home content** shows when expanding on Home tab  

### Console Check:

When app launches, you should see in Xcode console:
```
🔐 Checking iCloud status...
📍 Auto-starting location sharing...
🗺️ Loading circle data at location: [your coordinates]
```

If you see old logs or no logs, the build isn't fresh.

## Common Issues

### "Still showing old UI"

**Cause:** Xcode is using cached build  
**Fix:** Clean build folder + delete app + rebuild

### "Works in simulator, not device"

**Cause:** Different build targets or cached builds  
**Fix:** Clean derived data + rebuild for device specifically

### "Can't see drag handle"

**Cause:** Old version running on device  
**Fix:** Delete app from device + rebuild + reinstall

---

**TL;DR:**
1. Clean build (Shift + Cmd + K)
2. Delete app from iPhone
3. Rebuild and run on device
4. Should see new draggable sheet!



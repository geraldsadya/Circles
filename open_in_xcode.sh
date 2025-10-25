#!/bin/bash

echo "🍎 Opening Circle App in Xcode..."
echo "=================================="

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed or not in PATH"
    echo "Please install Xcode from the App Store first"
    exit 1
fi

# Check if project file exists
if [ ! -d "Circle.xcodeproj" ]; then
    echo "❌ Circle.xcodeproj folder not found"
    echo "Make sure you're in the correct directory"
    exit 1
fi

# Open the project in Xcode
echo "📱 Opening Circle.xcodeproj in Xcode..."
open Circle.xcodeproj

echo "✅ Project should now be opening in Xcode!"
echo ""
echo "If it doesn't open automatically:"
echo "1. Open Xcode manually"
echo "2. File → Open"
echo "3. Navigate to this folder"
echo "4. Select 'Circle.xcodeproj' folder"
echo "5. Click Open"

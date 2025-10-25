#!/bin/bash

echo "🔧 Fixing Circle project and preparing for transfer..."
echo "=================================================="

# Ensure all asset files exist
echo "✅ Creating missing asset files..."

# Create the main Assets.xcassets if it doesn't exist
mkdir -p "Circle/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "Circle/Resources/Assets.xcassets/AccentColor.colorset"
mkdir -p "Circle/Resources/Preview Content/Preview Assets.xcassets"

# Create Contents.json files
cat > "Circle/Resources/Assets.xcassets/Contents.json" << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

cat > "Circle/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "1024@1x.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

cat > "Circle/Resources/Assets.xcassets/AccentColor.colorset/Contents.json" << 'EOF'
{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

cat > "Circle/Resources/Preview Content/Preview Assets.xcassets/Contents.json" << 'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Create placeholder app icon
touch "Circle/Resources/Assets.xcassets/AppIcon.appiconset/1024@1x.png"

echo "✅ Asset files created successfully!"
echo ""
echo "📱 Next steps:"
echo "1. Copy the entire 'CircleOne' folder to your girlfriend's Mac"
echo "2. Make sure it's in a path WITHOUT spaces (e.g., ~/Downloads/CircleOne/)"
echo "3. Open Xcode on her Mac"
echo "4. File → Open → Select the CircleOne/Circle.xcodeproj FOLDER"
echo "5. Press Cmd+R to build and run!"
echo ""
echo "🎉 Your Circle app should now build successfully!"

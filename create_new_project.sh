#!/bin/bash

echo "🍎 Creating a fresh Xcode project for Circle App..."
echo "=================================================="

# Check if we can create a new project
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed or not in PATH"
    echo ""
    echo "SOLUTION:"
    echo "1. Install Xcode from the App Store"
    echo "2. Open Xcode and accept the license"
    echo "3. Run this script again"
    echo ""
    echo "Alternative: Use the web preview instead:"
    echo "open apple_preview.html"
    exit 1
fi

echo "✅ Xcode found, creating new project..."

# Create a new Xcode project
cd /Users/mac/CircleOne

# Create a simple project structure
mkdir -p CircleApp
cd CircleApp

# Create the main app file
cat > CircleApp.swift << 'EOF'
import SwiftUI

@main
struct CircleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF

# Create ContentView
cat > ContentView.swift << 'EOF'
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App Icon
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 2)
                    )
                    .overlay(
                        Text("C")
                            .font(.system(size: 40))
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    )
                
                VStack(spacing: 16) {
                    Text("Circle")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Social life, verified.")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Ready to prove it today?")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    Button(action: {}) {
                        Text("Sign in with Apple")
                            .font(.headline)
                            .foregroundColor(.primary)
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
                    
                    Button(action: {}) {
                        Text("Continue as Guest")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.systemGray5), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Circle")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
EOF

echo "✅ Created basic Circle app files"
echo ""
echo "📱 To open in Xcode:"
echo "1. Install Xcode from App Store"
echo "2. Open Xcode"
echo "3. File → New → Project"
echo "4. Choose 'iOS' → 'App'"
echo "5. Name it 'Circle'"
echo "6. Copy the code from CircleApp.swift and ContentView.swift"
echo ""
echo "🌐 Or use the web preview:"
echo "open ../apple_preview.html"

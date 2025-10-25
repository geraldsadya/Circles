//
//  IconGeneratorApp.swift
//  CircleIconGenerator
//
//  Created by Circle Team on 2024-01-15.
//

import SwiftUI
import AppKit

@main
struct IconGeneratorApp: App {
    var body: some Scene {
        WindowGroup {
            IconGeneratorView()
        }
    }
}

struct IconGeneratorView: View {
    @State private var isGenerating = false
    @State private var generatedCount = 0
    @State private var totalCount = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Circle App Icon Generator")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Apple Human Interface Guidelines Compliant")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Icon preview
            HStack(spacing: 20) {
                ForEach([60, 120, 240], id: \.self) { size in
                    VStack {
                        CircleIconView(size: CGFloat(size))
                        Text("\(size)x\(size)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            
            // Generate button
            Button(action: generateIcons) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isGenerating ? "Generating..." : "Generate All Icons")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
            .disabled(isGenerating)
            .padding(.horizontal, 40)
            
            // Progress
            if isGenerating {
                VStack {
                    ProgressView(value: Double(generatedCount), total: Double(totalCount))
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text("\(generatedCount) of \(totalCount) icons generated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 600)
    }
    
    private func generateIcons() {
        isGenerating = true
        generatedCount = 0
        totalCount = 18 // Total number of icons to generate
        
        // Generate icons in background
        DispatchQueue.global(qos: .userInitiated).async {
            let generator = AppIconGenerator()
            generator.generateAllIcons { count in
                DispatchQueue.main.async {
                    generatedCount = count
                    if count >= totalCount {
                        isGenerating = false
                        showCompletionAlert()
                    }
                }
            }
        }
    }
    
    private func showCompletionAlert() {
        let alert = NSAlert()
        alert.messageText = "Icons Generated Successfully!"
        alert.informativeText = "All app icons have been generated and saved to the AppIcon.appiconset folder."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct CircleIconView: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background with gradient
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.0, green: 0.48, blue: 1.0), Color(red: 0.0, green: 0.35, blue: 0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Main circle
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.6, height: size * 0.6)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.4, height: size * 0.4)
                )
            
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: size * 0.25, weight: .bold))
                .foregroundColor(Color.blue)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: size * 0.3, height: size * 0.3)
                )
            
            // Highlight
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: size, height: size)
        }
        .shadow(color: Color.black.opacity(0.1), radius: size * 0.05, x: 0, y: size * 0.02)
    }
}

class AppIconGenerator {
    
    private let iconSizes: [(width: Int, height: Int, scale: Int)] = [
        (20, 20, 1), (20, 20, 2), (20, 20, 3),
        (29, 29, 1), (29, 29, 2), (29, 29, 3),
        (40, 40, 1), (40, 40, 2), (40, 40, 3),
        (60, 60, 1), (60, 60, 2), (60, 60, 3),
        (76, 76, 1), (76, 76, 2),
        (83, 83, 2), // 83.5 rounded to 83
        (1024, 1024, 1)
    ]
    
    func generateAllIcons(completion: @escaping (Int) -> Void) {
        let outputDir = "/Users/mac/CircleOne/Circle/Resources/AppIcon.appiconset"
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        
        var count = 0
        
        for iconSize in iconSizes {
            let actualSize = iconSize.width * iconSize.scale
            let filename = generateFilename(width: iconSize.width, scale: iconSize.scale)
            
            generateIcon(size: actualSize, filename: filename, outputDir: outputDir)
            count += 1
            
            DispatchQueue.main.async {
                completion(count)
            }
            
            // Small delay to show progress
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
    
    private func generateFilename(width: Int, scale: Int) -> String {
        if width == 1024 {
            return "AppIcon-1024.png"
        } else if scale > 1 {
            return "AppIcon-\(width)@\(scale)x.png"
        } else {
            return "AppIcon-\(width).png"
        }
    }
    
    private func generateIcon(size: Int, filename: String, outputDir: String) {
        let iconView = CircleIconView(size: CGFloat(size))
        let renderer = ImageRenderer(content: iconView)
        renderer.proposedSize = .init(width: size, height: size)
        
        if let image = renderer.nsImage {
            let filePath = "\(outputDir)/\(filename)"
            
            if let tiffData = image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: URL(fileURLWithPath: filePath))
            }
        }
    }
}

#Preview {
    IconGeneratorView()
}

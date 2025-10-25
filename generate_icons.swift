#!/usr/bin/env swift

import Foundation
import AppKit

// Circle App Icon Generator
// Generates Apple-quality app icons following Human Interface Guidelines

class CircleIconGenerator {
    
    // Apple's recommended colors for Circle app
    private let primaryBlue = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
    private let secondaryBlue = NSColor(red: 0.0, green: 0.35, blue: 0.8, alpha: 1.0)
    private let accentPurple = NSColor(red: 0.5, green: 0.0, blue: 1.0, alpha: 1.0)
    private let backgroundWhite = NSColor.white
    private let shadowGray = NSColor.black.withAlphaComponent(0.1)
    
    // Required icon sizes
    private let iconSizes: [(width: Int, height: Int, scale: Int)] = [
        (20, 20, 1), (20, 20, 2), (20, 20, 3),
        (29, 29, 1), (29, 29, 2), (29, 29, 3),
        (40, 40, 1), (40, 40, 2), (40, 40, 3),
        (60, 60, 1), (60, 60, 2), (60, 60, 3),
        (76, 76, 1), (76, 76, 2),
        (83, 83, 2), // 83.5 rounded to 83
        (1024, 1024, 1)
    ]
    
    func generateAllIcons() {
        let outputDir = "/Users/mac/CircleOne/Circle/Resources/AppIcon.appiconset"
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        
        print("🎨 Generating Circle App Icons...")
        print("Following Apple Human Interface Guidelines")
        print(String(repeating: "=", count: 50))
        
        for iconSize in iconSizes {
            let actualSize = iconSize.width * iconSize.scale
            let filename = generateFilename(width: iconSize.width, scale: iconSize.scale)
            
            generateIcon(size: actualSize, filename: filename, outputDir: outputDir)
            print("Generated: \(filename) (\(actualSize)x\(actualSize))")
        }
        
        print(String(repeating: "=", count: 50))
        print("✅ All app icons generated successfully!")
        print("📁 Icons saved to: \(outputDir)")
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
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        
        // Create the icon
        drawCircleIcon(size: size)
        
        image.unlockFocus()
        
        // Save as PNG
        let filePath = "\(outputDir)/\(filename)"
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: URL(fileURLWithPath: filePath))
        }
    }
    
    private func drawCircleIcon(size: Int) {
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let cornerRadius = CGFloat(size) * 0.22 // Apple's recommended corner radius
        
        // Background with gradient
        let gradient = NSGradient(colors: [primaryBlue, secondaryBlue])
        let backgroundPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        gradient?.draw(in: backgroundPath, angle: 135)
        
        // Main white circle
        let circleSize = CGFloat(size) * 0.6
        let circleX = (CGFloat(size) - circleSize) / 2
        let circleY = (CGFloat(size) - circleSize) / 2
        let circleRect = NSRect(x: circleX, y: circleY, width: circleSize, height: circleSize)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        backgroundWhite.setFill()
        circlePath.fill()
        
        // Inner circle with subtle gradient
        let innerSize = CGFloat(size) * 0.4
        let innerX = (CGFloat(size) - innerSize) / 2
        let innerY = (CGFloat(size) - innerSize) / 2
        let innerRect = NSRect(x: innerX, y: innerY, width: innerSize, height: innerSize)
        let innerPath = NSBezierPath(ovalIn: innerRect)
        
        let innerGradient = NSGradient(colors: [
            primaryBlue.withAlphaComponent(0.1),
            accentPurple.withAlphaComponent(0.1)
        ])
        innerGradient?.draw(in: innerPath, angle: 135)
        
        // Checkmark circle background
        let checkmarkBgSize = CGFloat(size) * 0.3
        let checkmarkBgX = (CGFloat(size) - checkmarkBgSize) / 2
        let checkmarkBgY = (CGFloat(size) - checkmarkBgSize) / 2
        let checkmarkBgRect = NSRect(x: checkmarkBgX, y: checkmarkBgY, width: checkmarkBgSize, height: checkmarkBgSize)
        let checkmarkBgPath = NSBezierPath(ovalIn: checkmarkBgRect)
        backgroundWhite.setFill()
        checkmarkBgPath.fill()
        
        // Checkmark symbol
        let checkmarkSize = CGFloat(size) * 0.25
        let checkmarkX = (CGFloat(size) - checkmarkSize) / 2
        let checkmarkY = (CGFloat(size) - checkmarkSize) / 2
        
        // Draw checkmark
        let checkmarkPath = NSBezierPath()
        checkmarkPath.move(to: NSPoint(x: checkmarkX + checkmarkSize * 0.2, y: checkmarkY + checkmarkSize * 0.5))
        checkmarkPath.line(to: NSPoint(x: checkmarkX + checkmarkSize * 0.4, y: checkmarkY + checkmarkSize * 0.7))
        checkmarkPath.line(to: NSPoint(x: checkmarkX + checkmarkSize * 0.8, y: checkmarkY + checkmarkSize * 0.3))
        
        primaryBlue.setStroke()
        checkmarkPath.lineWidth = CGFloat(size) * 0.02
        checkmarkPath.stroke()
        
        // Subtle highlight
        let highlightPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        let highlightGradient = NSGradient(colors: [
            NSColor.white.withAlphaComponent(0.3),
            NSColor.clear
        ])
        highlightGradient?.draw(in: highlightPath, angle: 135)
    }
}

// Run the generator
let generator = CircleIconGenerator()
generator.generateAllIcons()

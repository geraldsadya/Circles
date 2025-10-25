#!/usr/bin/env python3
"""
Circle App Icon Generator
Generates Apple-quality app icons following Human Interface Guidelines
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter
import colorsys

class CircleIconGenerator:
    
    def __init__(self):
        # Apple's recommended colors for Circle app
        self.colors = {
            'primary_blue': (0, 122, 255),      # iOS Blue
            'secondary_blue': (0, 89, 204),     # Darker Blue
            'accent_purple': (128, 0, 255),     # Purple accent
            'background_white': (255, 255, 255), # White
            'shadow_gray': (0, 0, 0, 25),       # 10% black
            'highlight_white': (255, 255, 255, 77) # 30% white
        }
        
        # Required icon sizes (width, height, scale)
        self.icon_sizes = [
            (20, 20, 1), (20, 20, 2), (20, 20, 3),
            (29, 29, 1), (29, 29, 2), (29, 29, 3),
            (40, 40, 1), (40, 40, 2), (40, 40, 3),
            (60, 60, 1), (60, 60, 2), (60, 60, 3),
            (76, 76, 1), (76, 76, 2),
            (83.5, 83.5, 2),
            (1024, 1024, 1)  # App Store
        ]
    
    def create_gradient_background(self, size, start_color, end_color):
        """Create a gradient background"""
        image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        
        # Create gradient by drawing lines
        for y in range(size):
            # Calculate color interpolation
            ratio = y / size
            r = int(start_color[0] * (1 - ratio) + end_color[0] * ratio)
            g = int(start_color[1] * (1 - ratio) + end_color[1] * ratio)
            b = int(start_color[2] * (1 - ratio) + end_color[2] * ratio)
            
            draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
        
        return image
    
    def create_circle_with_checkmark(self, size):
        """Create the main Circle app icon"""
        # Calculate dimensions
        corner_radius = int(size * 0.22)  # Apple's recommended corner radius
        main_circle_size = int(size * 0.6)
        inner_circle_size = int(size * 0.4)
        checkmark_size = int(size * 0.25)
        
        # Create base image
        image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        
        # Create gradient background
        bg_image = self.create_gradient_background(
            size, 
            self.colors['primary_blue'], 
            self.colors['secondary_blue']
        )
        
        # Apply rounded corners
        mask = Image.new('L', (size, size), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.rounded_rectangle(
            [(0, 0), (size, size)], 
            radius=corner_radius, 
            fill=255
        )
        
        # Apply mask to background
        image.paste(bg_image, (0, 0), mask)
        
        # Draw main white circle
        circle_x = (size - main_circle_size) // 2
        circle_y = (size - main_circle_size) // 2
        draw.ellipse(
            [circle_x, circle_y, circle_x + main_circle_size, circle_y + main_circle_size],
            fill=self.colors['background_white']
        )
        
        # Draw inner circle with subtle gradient
        inner_x = (size - inner_circle_size) // 2
        inner_y = (size - inner_circle_size) // 2
        inner_gradient = self.create_gradient_background(
            inner_circle_size,
            (0, 122, 255, 25),  # 10% opacity blue
            (128, 0, 255, 25)   # 10% opacity purple
        )
        image.paste(inner_gradient, (inner_x, inner_y), inner_gradient)
        
        # Draw checkmark
        checkmark_x = (size - checkmark_size) // 2
        checkmark_y = (size - checkmark_size) // 2
        
        # Create checkmark circle background
        checkmark_bg_size = int(size * 0.3)
        checkmark_bg_x = (size - checkmark_bg_size) // 2
        checkmark_bg_y = (size - checkmark_bg_size) // 2
        draw.ellipse(
            [checkmark_bg_x, checkmark_bg_y, 
             checkmark_bg_x + checkmark_bg_size, checkmark_bg_y + checkmark_bg_size],
            fill=self.colors['background_white']
        )
        
        # Draw checkmark symbol
        checkmark_path = self.create_checkmark_path(checkmark_x, checkmark_y, checkmark_size)
        draw.polygon(checkmark_path, fill=self.colors['primary_blue'])
        
        # Add subtle highlight
        highlight = self.create_highlight_overlay(size)
        image = Image.alpha_composite(image, highlight)
        
        # Add shadow
        shadow = self.create_shadow(size)
        final_image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        final_image.paste(shadow, (0, 0), shadow)
        final_image.paste(image, (0, 0), image)
        
        return final_image
    
    def create_checkmark_path(self, x, y, size):
        """Create checkmark path coordinates"""
        # Simple checkmark shape
        width = size
        height = size
        
        # Checkmark points (simplified)
        points = [
            (x + width * 0.2, y + height * 0.5),
            (x + width * 0.4, y + height * 0.7),
            (x + width * 0.8, y + height * 0.3)
        ]
        
        return points
    
    def create_highlight_overlay(self, size):
        """Create subtle highlight overlay"""
        image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        
        # Create gradient highlight
        highlight_size = int(size * 0.8)
        highlight_x = int(size * 0.1)
        highlight_y = int(size * 0.1)
        
        # Draw subtle highlight
        draw.ellipse(
            [highlight_x, highlight_y, 
             highlight_x + highlight_size, highlight_y + highlight_size],
            fill=self.colors['highlight_white']
        )
        
        return image
    
    def create_shadow(self, size):
        """Create subtle shadow"""
        shadow_size = int(size * 1.1)
        shadow_offset = int(size * 0.02)
        
        image = Image.new('RGBA', (shadow_size, shadow_size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        
        # Draw shadow
        draw.ellipse(
            [0, 0, shadow_size, shadow_size],
            fill=self.colors['shadow_gray']
        )
        
        # Apply blur
        image = image.filter(ImageFilter.GaussianBlur(radius=2))
        
        return image
    
    def generate_all_icons(self, output_dir):
        """Generate all required app icon sizes"""
        os.makedirs(output_dir, exist_ok=True)
        
        for width, height, scale in self.icon_sizes:
            # Calculate actual size
            actual_size = int(width * scale)
            
            # Generate filename
            if scale > 1:
                filename = f"AppIcon-{int(width)}@{int(scale)}x.png"
            else:
                filename = f"AppIcon-{int(width)}.png"
            
            # Special case for App Store icon
            if width == 1024:
                filename = "AppIcon-1024.png"
            
            # Generate icon
            icon = self.create_circle_with_checkmark(actual_size)
            
            # Save icon
            filepath = os.path.join(output_dir, filename)
            icon.save(filepath, 'PNG')
            print(f"Generated: {filename} ({actual_size}x{actual_size})")
    
    def validate_icon(self, image_path):
        """Validate icon follows Apple's guidelines"""
        try:
            with Image.open(image_path) as img:
                width, height = img.size
                
                # Check if square
                if width != height:
                    return False, "Icon must be square"
                
                # Check minimum size for App Store
                if width < 1024 and "1024" in image_path:
                    return False, "App Store icon must be at least 1024x1024"
                
                # Check format
                if img.format != 'PNG':
                    return False, "Icon must be PNG format"
                
                return True, "Icon is valid"
                
        except Exception as e:
            return False, f"Error validating icon: {str(e)}"

def main():
    """Main function to generate all app icons"""
    generator = CircleIconGenerator()
    
    # Set output directory
    output_dir = "/Users/mac/CircleOne/Circle/Resources/AppIcon.appiconset"
    
    print("🎨 Generating Circle App Icons...")
    print("Following Apple Human Interface Guidelines")
    print("=" * 50)
    
    # Generate all icons
    generator.generate_all_icons(output_dir)
    
    print("=" * 50)
    print("✅ All app icons generated successfully!")
    print(f"📁 Icons saved to: {output_dir}")
    print("\n📋 Generated icons:")
    
    # List generated files
    for filename in sorted(os.listdir(output_dir)):
        if filename.endswith('.png'):
            filepath = os.path.join(output_dir, filename)
            is_valid, message = generator.validate_icon(filepath)
            status = "✅" if is_valid else "❌"
            print(f"  {status} {filename} - {message}")

if __name__ == "__main__":
    main()

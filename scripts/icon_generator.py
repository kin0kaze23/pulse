#!/usr/bin/env python3
"""
Script to generate Pulse app icon in various sizes
Creates an iconic representation for memory/monitoring app
"""

import os
from PIL import Image, ImageDraw, ImageFont
import io


def create_pulse_icon():
    """Create the main Pulse app icon with vibrant blue-green gradient"""

    # Create the main 1024x1024 master icon
    master_size = 1024

    # Create gradient background with radial effect
    img = Image.new("RGBA", (master_size, master_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw a sophisticated gradient circle (Pulse inspired)
    center_x, center_y = master_size // 2, master_size // 2
    radius = master_size // 2 - 20  # Leave small margin

    # Fill with sophisticated dark blue-to-purple gradient
    for r in range(radius, 0, -1):
        # Calculate the distance from center normalized
        distance = r / radius
        # Create gradient from dark purple (#2D1B69) to lighter blue (#4A90E2)
        red = int(45 * (1 - distance) + 74 * distance)
        green = int(27 * (1 - distance) + 144 * distance)
        blue = int(105 * (1 - distance) + 226 * distance)
        alpha = 255

        border_color = (red, green, blue, alpha)

        # Draw circle outline
        bbox = [center_x - r, center_y - r, center_x + r, center_y + r]

        # Reduce stroke width near center to avoid dense overlapping
        thickness = max(1, int(5 * distance))
        for i in range(thickness):
            outline_bbox = [bbox[0] - i, bbox[1] - i, bbox[2] + i, bbox[3] + i]
            draw.ellipse(outline_bbox, outline=border_color)

    # Create the main 'P' in the center with clean typography
    try:
        # Attempt to use system bold font if available
        font = ImageFont.truetype("Arial Bold.ttf", size=int(master_size * 0.3))
    except:
        # Use default if Arial Bold isn't available
        try:
            font = ImageFont.truetype("Arial.ttf", size=int(master_size * 0.3))
        except:
            font = ImageFont.load_default()
            print("Warning: Using default font. Install Arial for better icon.")

    # Draw "P" centered
    text = "P"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    text_x = center_x - text_width // 2
    text_y = (
        center_y - text_height // 2 + int(text_height * 0.1)
    )  # Slight vertical adjustment

    # Use white text for good contrast against dark background
    draw.text((text_x, text_y), text, fill=(255, 255, 255, 255), font=font)

    # Add a subtle "sine wave" line representing pulses
    wave_points = []
    for x in range(int(center_x - radius * 0.7), int(center_x + radius * 0.7), 10):
        # Calculate sine wave: y = center_y + amplitude*sin(frequency*x)
        import math

        y = center_y + 50 * math.sin(
            (x - center_x) * 0.03
        )  # Amplitude = 50, frequency=0.03
        wave_points.append((x, y))

    # Draw the wave with a brighter accent color
    for i in range(len(wave_points) - 1):
        draw.line(
            [wave_points[i], wave_points[i + 1]], fill=(155, 226, 255, 255), width=8
        )

    return img


def create_iconset(icon_img):
    """Create various sizes for macOS iconset"""

    # Define macOS icon sizes
    sizes = [
        (16, 16),
        (32, 32),
        (64, 64),
        (128, 128),
        (256, 256),
        (512, 512),
        (1024, 1024),
    ]

    # Prepare iconset directory and files
    # Use relative path from script location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    iconset_path = os.path.join(
        script_dir,
        "Pulse.app/Contents/Resources/AppIcon.iconset"
    )
    os.makedirs(iconset_path, exist_ok=True)

    # Create JSON info file for the iconset
    json_content = """{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}"""

    with open(
        os.path.join(iconset_path, "Contents.json"),
        "w",
    ) as f:
        f.write(json_content)

    # Generate each size with appropriate filenames
    size_names = {
        (16, 16): ["icon_16x16.png", "icon_16x16@2x.png"],
        (32, 32): ["icon_32x32.png", "icon_32x32@2x.png"],
        (128, 128): ["icon_128x128.png", "icon_128x128@2x.png"],
        (256, 256): ["icon_256x256.png", "icon_256x256@2x.png"],
        (512, 512): ["icon_512x512.png", "icon_512x512@2x.png"],
        (1024, 1024): ["icon_512x512@2x.png"],  # For the largest size
    }

    master_name_map = {
        (16, 16): "icon_16x16.png",
        (32, 32): "icon_32x32.png",
        (64, 64): "icon_64x64.png",
        (128, 128): "icon_128x128.png",
        (256, 256): "icon_256x256.png",
        (512, 512): "icon_512x512.png",
        (1024, 1024): "icon_1024x1024.png",
    }

    for size in sizes:
        resized_icon = icon_img.resize((size[0], size[1]), Image.Resampling.LANCZOS)
        filename = master_name_map[size]
        file_path = os.path.join(iconset_path, filename)
        resized_icon.save(file_path, "PNG")


if __name__ == "__main__":
    print("Creating Pulse app icon...")
    # Install PIL if not already present
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Installing Pillow...")
        import subprocess

        subprocess.run(["pip3", "install", "pillow"])
        from PIL import Image, ImageDraw, ImageFont

    # Create master icon
    master_icon = create_pulse_icon()

    # Save different sizes for iconset
    create_iconset(master_icon)

    print("Pulse app icons generated successfully!")
    print("Iconset created in: Pulse.app/Contents/Resources/AppIcon.iconset/")

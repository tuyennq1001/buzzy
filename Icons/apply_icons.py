#!/usr/bin/env python3
"""
Utility script to generate and apply App Icon and Menu Bar icons into Tomik assets.
Usage:
    python3 Icons/apply_icons.py --app-icon option1 --menubar-style A
"""
import os
import sys
import argparse
from PIL import Image

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(BASE_DIR)
ASSETS_DIR = os.path.join(PROJECT_DIR, "Tomik", "Assets.xcassets")
APPICON_DIR = os.path.join(ASSETS_DIR, "AppIcon.appiconset")

BRAIN_DIR = "/Users/tuyennq1001/.gemini/antigravity/brain/b102fc83-af0b-41a4-bfaf-c542eb8a1400"

def install_app_icon(src_img_path):
    print(f"Applying App Icon from: {src_img_path}")
    img = Image.open(src_img_path).convert("RGBA")
    
    # Target sizes for macOS AppIcon
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    
    for size, filename in sizes:
        dest_path = os.path.join(APPICON_DIR, filename)
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(dest_path, "PNG")
        print(f"  Generated {filename} ({size}x{size})")
        
    # Also save master 1024x1024 in Icons/
    master_path = os.path.join(BASE_DIR, "Tomik.png")
    img.resize((1024, 1024), Image.Resampling.LANCZOS).save(master_path, "PNG")
    print(f"  Updated master {master_path}")

def install_menubar_icons(menubar_src_prefix):
    print(f"Applying Menu Bar icons from prefix: {menubar_src_prefix}")
    
    imagesets = [
        "BarIconIdle.imageset",
        "BarIconWork.imageset",
        "BarIconShortRest.imageset",
        "BarIconLongRest.imageset",
    ]
    
    for imageset in imagesets:
        target_dir = os.path.join(ASSETS_DIR, imageset)
        os.makedirs(target_dir, exist_ok=True)
        
        # 16x16, 32x32, 48x48
        scales = [
            (16, "icon_16x16.png"),
            (32, "icon_16x16@2x.png"),
            (48, "icon_16x16@3x.png")
        ]
        
        for size, filename in scales:
            src_file = f"{menubar_src_prefix}_{size}.png"
            dest_file = os.path.join(target_dir, filename)
            if os.path.exists(src_file):
                img = Image.open(src_file).convert("RGBA")
                img.save(dest_file, "PNG")
                print(f"  Saved {imageset}/{filename}")
            else:
                print(f"  Warning: {src_file} not found!")

    # Also update Icons/tomato-filled.png master
    master_src = f"{menubar_src_prefix}_512.png"
    if os.path.exists(master_src):
        master_img = Image.open(master_src).convert("RGBA")
        master_img.save(os.path.join(BASE_DIR, "tomato-filled.png"), "PNG")
        print("  Updated Icons/tomato-filled.png")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-icon", choices=["1", "2", "3"], default="1")
    parser.add_argument("--menubar", choices=["A", "B", "C", "D"], default="A")
    args = parser.parse_args()
    
    app_map = {
        "1": f"{BRAIN_DIR}/option1_squircle_3d.jpg",
        "2": f"{BRAIN_DIR}/option2_toy_pastel.jpg",
        "3": f"{BRAIN_DIR}/option3_vector_2d.jpg",
    }
    
    bar_map = {
        "A": f"{BRAIN_DIR}/scratch/menubar_v2_kawaii_dots",
        "B": f"{BRAIN_DIR}/scratch/menubar_v2_happy_arcs",
        "C": f"{BRAIN_DIR}/scratch/menubar_v2_minimalist",
        "D": f"{BRAIN_DIR}/scratch/menubar_v2_wink",
    }
    
    install_app_icon(app_map[args.app_icon])
    install_menubar_icons(bar_map[args.menubar])
    print("Done applying icons!")

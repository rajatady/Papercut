#!/usr/bin/env python3
"""
Render marketing App Store screenshots from HTML frames + raw app screenshots.
Uses Playwright to render at exact App Store dimensions.
"""
import os
import sys
import json

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCREENSHOTS_DIR = os.path.join(PROJECT_DIR, "screenshots")
IPAD_DIR = os.path.join(SCREENSHOTS_DIR, "ipad")
OUTPUT_DIR = os.path.join(SCREENSHOTS_DIR, "marketing")
HTML_FILE = os.path.join(PROJECT_DIR, "scripts", "marketing-frames.html")

os.makedirs(OUTPUT_DIR, exist_ok=True)

# Map slide IDs to source screenshot paths
IPHONE_SLIDES = {
    "iphone-1": {
        "images": {"iphone-1-img": os.path.join(SCREENSHOTS_DIR, "iphone_03_feed_light.png")},
        "width": 1290, "height": 2796,
        "output": "appstore_iphone_01_hero.png"
    },
    "iphone-2": {
        "images": {"iphone-2-img": os.path.join(SCREENSHOTS_DIR, "iphone_04_feed_dark.png")},
        "width": 1290, "height": 2796,
        "output": "appstore_iphone_02_ai_summaries.png"
    },
    "iphone-3": {
        "images": {"iphone-3-img": os.path.join(SCREENSHOTS_DIR, "iphone_01_onboarding_welcome.png")},
        "width": 1290, "height": 2796,
        "output": "appstore_iphone_03_search.png"
    },
    "iphone-4": {
        "images": {"iphone-4-img": os.path.join(SCREENSHOTS_DIR, "iphone_02_onboarding_categories.png")},
        "width": 1290, "height": 2796,
        "output": "appstore_iphone_04_categories.png"
    },
    "iphone-5": {
        "images": {"iphone-5-img": os.path.join(SCREENSHOTS_DIR, "iphone_04_feed_dark.png")},
        "width": 1290, "height": 2796,
        "output": "appstore_iphone_05_privacy.png"
    },
    "iphone-6": {
        "images": {"iphone-6-img": os.path.join(SCREENSHOTS_DIR, "iphone_07_trending.png")},
        "width": 1290, "height": 2796,
        "output": "appstore_iphone_06_trending.png"
    },
}

IPAD_SLIDES = {
    "ipad-1": {
        "images": {"ipad-1-img": os.path.join(IPAD_DIR, "feed_light.png")},
        "width": 2064, "height": 2752,
        "output": "appstore_ipad_01_hero.png"
    },
    "ipad-2": {
        "images": {"ipad-2-img": os.path.join(IPAD_DIR, "feed_light.png")},
        "width": 2064, "height": 2752,
        "output": "appstore_ipad_02_ai_summaries.png"
    },
    "ipad-3": {
        "images": {"ipad-3-img": os.path.join(IPAD_DIR, "feed_dark.png")},
        "width": 2064, "height": 2752,
        "output": "appstore_ipad_03_dark.png"
    },
    "ipad-4": {
        "images": {"ipad-4-img": os.path.join(IPAD_DIR, "search.png")},
        "width": 2064, "height": 2752,
        "output": "appstore_ipad_04_search.png"
    },
}

ALL_SLIDES = {**IPHONE_SLIDES, **IPAD_SLIDES}

print(f"Rendering {len(ALL_SLIDES)} marketing screenshots...")
print(f"Output: {OUTPUT_DIR}")
print()

# Output the config as JSON for the Playwright script to consume
config = {
    "htmlFile": f"file://{HTML_FILE}",
    "outputDir": OUTPUT_DIR,
    "slides": ALL_SLIDES
}

print(json.dumps(config, indent=2))

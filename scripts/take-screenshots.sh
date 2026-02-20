#!/bin/bash
set -euo pipefail

# ============================================================
# Papercut App Store Screenshot Automation
# ============================================================
# Runs UI tests on iPhone & iPad simulators, extracts screenshots
# from the xcresult bundle, and saves them to ./screenshots/
#
# Required sizes:
#   iPhone 6.5": 1290×2796 (iPhone 16 Pro Max)
#   iPad 12.9":  2048×2732 (iPad Pro 13-inch M4)
# ============================================================

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCREENSHOTS_DIR="$PROJECT_DIR/screenshots"
RESULT_BUNDLE="$PROJECT_DIR/build/screenshots.xcresult"

# Clean up
rm -rf "$RESULT_BUNDLE"
mkdir -p "$SCREENSHOTS_DIR"
mkdir -p "$PROJECT_DIR/build"

echo "📱 Papercut Screenshot Automation"
echo "=================================="

# ── Helper: Override status bar for clean screenshots ──
override_status_bar() {
    local udid="$1"
    xcrun simctl status_bar "$udid" override \
        --time "9:41" \
        --batteryState charged \
        --batteryLevel 100 \
        --wifiBars 3 \
        --cellularBars 4 \
        --operatorName "" \
        --dataNetwork "wifi" 2>/dev/null || true
}

# ── Helper: Extract screenshots from xcresult ──
extract_screenshots() {
    local result_bundle="$1"
    local output_dir="$2"
    local prefix="$3"

    echo "📦 Extracting screenshots from xcresult..."

    # Use xcresulttool to find attachments
    xcrun xcresulttool get --path "$result_bundle" --format json 2>/dev/null | \
        python3 -c "
import json, sys, subprocess, os

data = json.load(sys.stdin)

def find_attachments(obj, path=''):
    if isinstance(obj, dict):
        # Check if this is an attachment reference
        if obj.get('_type', {}).get('_name') == 'ActionTestAttachment':
            name = obj.get('name', {}).get('_value', '')
            payload_ref = obj.get('payloadRef', {}).get('id', {}).get('_value', '')
            if payload_ref and name:
                output_path = os.path.join('$output_dir', '${prefix}_' + name + '.png')
                subprocess.run([
                    'xcrun', 'xcresulttool', 'get',
                    '--path', '$result_bundle',
                    '--id', payload_ref,
                    '--output-path', output_path
                ], check=True)
                print(f'  ✅ {name} -> {os.path.basename(output_path)}')
        for v in obj.values():
            find_attachments(v, path)
    elif isinstance(obj, list):
        for item in obj:
            find_attachments(item, path)

find_attachments(data)
" 2>/dev/null || echo "  ⚠️  Falling back to manual extraction..."

    # Fallback: try extracting all PNG attachments
    if [ -z "$(ls -A "$output_dir"/${prefix}_*.png 2>/dev/null)" ]; then
        echo "  Using attachment export fallback..."
        xcrun xcresulttool export --path "$result_bundle" --output-path "$output_dir" --type file 2>/dev/null || true
    fi
}

# ── iPhone Screenshots ──
echo ""
echo "📱 iPhone 16 Pro Max (6.5\" - 1290×2796)"
echo "──────────────────────────────────────────"

IPHONE_DEVICE="iPhone 16 Pro Max"
IPHONE_UDID=$(xcrun simctl list devices available | grep "$IPHONE_DEVICE" | head -1 | grep -oE '[A-F0-9-]{36}')

if [ -z "$IPHONE_UDID" ]; then
    echo "❌ $IPHONE_DEVICE simulator not found"
    exit 1
fi

echo "  Booting $IPHONE_DEVICE ($IPHONE_UDID)..."
xcrun simctl boot "$IPHONE_UDID" 2>/dev/null || true
sleep 3

echo "  Setting clean status bar..."
override_status_bar "$IPHONE_UDID"

echo "  Running UI tests (this takes a while)..."
xcodebuild test \
    -project "$PROJECT_DIR/Papercut.xcodeproj" \
    -scheme "PapercutUITests" \
    -destination "platform=iOS Simulator,id=$IPHONE_UDID" \
    -resultBundlePath "$RESULT_BUNDLE" \
    -only-testing:PapercutUITests/PapercutScreenshotTests \
    2>&1 | grep -E "(Test Case|✓|✗|error:|FAILED|PASSED|Compiling|Linking)" || true

echo ""
extract_screenshots "$RESULT_BUNDLE" "$SCREENSHOTS_DIR" "iphone"

# Reset status bar
xcrun simctl status_bar "$IPHONE_UDID" clear 2>/dev/null || true

# ── iPad Screenshots ──
echo ""
echo "📱 iPad Pro 13-inch (12.9\" - 2048×2732)"
echo "──────────────────────────────────────────"

IPAD_DEVICE="iPad Pro 13-inch (M4)"
IPAD_UDID=$(xcrun simctl list devices available | grep "$IPAD_DEVICE" | head -1 | grep -oE '[A-F0-9-]{36}')

if [ -z "$IPAD_UDID" ]; then
    echo "⚠️  $IPAD_DEVICE simulator not found, skipping iPad screenshots"
else
    # Remove old result bundle for iPad run
    IPAD_RESULT_BUNDLE="$PROJECT_DIR/build/screenshots-ipad.xcresult"
    rm -rf "$IPAD_RESULT_BUNDLE"

    echo "  Booting $IPAD_DEVICE ($IPAD_UDID)..."
    xcrun simctl boot "$IPAD_UDID" 2>/dev/null || true
    sleep 3

    echo "  Setting clean status bar..."
    override_status_bar "$IPAD_UDID"

    echo "  Running UI tests on iPad..."
    xcodebuild test \
        -project "$PROJECT_DIR/Papercut.xcodeproj" \
        -scheme "PapercutUITests" \
        -destination "platform=iOS Simulator,id=$IPAD_UDID" \
        -resultBundlePath "$IPAD_RESULT_BUNDLE" \
        -only-testing:PapercutUITests/PapercutScreenshotTests \
        2>&1 | grep -E "(Test Case|✓|✗|error:|FAILED|PASSED|Compiling|Linking)" || true

    echo ""
    extract_screenshots "$IPAD_RESULT_BUNDLE" "$SCREENSHOTS_DIR" "ipad"

    xcrun simctl status_bar "$IPAD_UDID" clear 2>/dev/null || true
fi

# ── Summary ──
echo ""
echo "=================================="
echo "📸 Screenshots saved to: $SCREENSHOTS_DIR"
echo ""
ls -la "$SCREENSHOTS_DIR"/*.png 2>/dev/null || echo "  No screenshots found — check test output above for errors"
echo ""
echo "Next: Use these raw screenshots to create marketing frames"
echo "  or upload directly to App Store Connect."

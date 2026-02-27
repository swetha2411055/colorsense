#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  ColorSense — One-Click APK Builder
#  Run this script from inside the colorsense_flutter/ folder
#  Works on: macOS, Linux, Windows (Git Bash / WSL)
# ═══════════════════════════════════════════════════════════════════

set -e
CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${CYAN}▶${NC} $1"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; exit 1; }
warn() { echo -e "${YELLOW}!${NC} $1"; }

echo ""
echo -e "${CYAN}╔════════════════════════════════╗"
echo -e "║   ColorSense APK Builder       ║"
echo -e "╚════════════════════════════════╝${NC}"
echo ""

# ── Check we're in the right directory ─────────────────────────────
[ -f "pubspec.yaml" ] || err "Run this script from inside the colorsense_flutter/ folder"

# ── Step 1: Install Flutter if missing ─────────────────────────────
if ! command -v flutter &>/dev/null; then
    log "Flutter not found. Installing..."

    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &>/dev/null; then
            brew install flutter
        else
            warn "Homebrew not found. Installing Flutter manually..."
            curl -Lo flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.24.5-stable.zip
            unzip -q flutter.tar.xz -d ~/
            export PATH="$PATH:$HOME/flutter/bin"
            echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -Lo /tmp/flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
        tar xf /tmp/flutter.tar.xz -C ~/
        export PATH="$PATH:$HOME/flutter/bin"
        echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
    else
        err "Please install Flutter manually from https://flutter.dev then re-run this script"
    fi
fi
ok "Flutter: $(flutter --version 2>/dev/null | head -1)"

# ── Step 2: Accept Android licenses ────────────────────────────────
log "Accepting Android licenses..."
yes | flutter doctor --android-licenses 2>/dev/null || true

# ── Step 3: Check YOLOv9 model ─────────────────────────────────────
if [ ! -f "assets/models/yolov9_tiny.tflite" ]; then
    warn "YOLOv9 model not found. App will use fallback detection."
    warn "To add later:"
    warn "  pip install ultralytics"
    warn "  python -c \"from ultralytics import YOLO; YOLO('yolov9t.pt').export(format='tflite', imgsz=640, int8=True)\""
    warn "  mv yolov9t_saved_model/yolov9t_int8.tflite assets/models/yolov9_tiny.tflite"
else
    ok "YOLOv9 model found"
fi

# ── Step 4: flutter pub get ─────────────────────────────────────────
log "Fetching packages..."
flutter pub get
ok "Packages ready"

# ── Step 5: Build APK ───────────────────────────────────────────────
log "Building release APK (this takes 2–5 minutes first time)..."
flutter build apk --release --split-per-abi

APK="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
[ -f "$APK" ] || APK="build/app/outputs/flutter-apk/app-release.apk"

ok "APK built: $APK"
SIZE=$(du -sh "$APK" | cut -f1)
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  APK ready! Size: $SIZE${NC}"
echo -e "${GREEN}  Location: $APK${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""

# ── Step 6: Install on device ──────────────────────────────────────
if command -v adb &>/dev/null; then
    DEVICES=$(adb devices | grep -v "List" | grep "device$" | wc -l)
    if [ "$DEVICES" -gt 0 ]; then
        log "Android device detected! Installing..."
        adb install -r "$APK"
        ok "Installed on device! Open 'ColorSense' on your phone."
    else
        warn "No device connected via USB."
        echo "  To install: connect phone via USB with USB Debugging enabled, then run:"
        echo "  adb install $APK"
    fi
else
    warn "adb not found."
fi

echo ""
echo "  Manual install options:"
echo "  1. Copy APK to phone via USB cable (drag and drop)"
echo "  2. Send to yourself via WhatsApp / Telegram / Google Drive"
echo "  3. Email the APK to yourself and open it on your phone"
echo "  On phone: tap the APK → Allow 'Install unknown apps' → Install"
echo ""

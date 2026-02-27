#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# ColorSense — Build & Deploy Script
# Run from the project root: bash build.sh
# ──────────────────────────────────────────────────────────────────────────────

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "${CYAN}[ColorSense]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo -e "${CYAN}"
echo "  ██████╗ ██████╗ ██╗      ██████╗ ██████╗ "
echo " ██╔════╝██╔═══██╗██║     ██╔═══██╗██╔══██╗"
echo " ██║     ██║   ██║██║     ██║   ██║██████╔╝"
echo " ██║     ██║   ██║██║     ██║   ██║██╔══██╗"
echo " ╚██████╗╚██████╔╝███████╗╚██████╔╝██║  ██║"
echo "  ╚═════╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝"
echo -e " ${NC}ColorSense — Flutter Build Script\n"

# ── 1. Prerequisites check ───────────────────────────────────────────────────
log "Checking prerequisites..."
command -v flutter >/dev/null 2>&1 || err "Flutter not found. Install from https://flutter.dev"
command -v dart    >/dev/null 2>&1 || err "Dart not found. Install Flutter SDK."
flutter doctor --android-licenses -y >/dev/null 2>&1 || true
ok "Flutter $(flutter --version | head -1 | awk '{print $2}')"

# ── 2. YOLOv9 model check ────────────────────────────────────────────────────
log "Checking YOLOv9 model..."
if [ -f "assets/models/yolov9_tiny.tflite" ]; then
    SIZE=$(du -sh assets/models/yolov9_tiny.tflite | cut -f1)
    ok "YOLOv9 model found ($SIZE)"
else
    warn "YOLOv9 model NOT found at assets/models/yolov9_tiny.tflite"
    warn "App will run with fallback region detection."
    warn "To add the model:"
    warn "  pip install ultralytics"
    warn "  python -c \"from ultralytics import YOLO; YOLO('yolov9t.pt').export(format='tflite', imgsz=640, int8=True)\""
    warn "  mv yolov9t_saved_model/yolov9t_int8.tflite assets/models/yolov9_tiny.tflite"
fi

# ── 3. API key check ─────────────────────────────────────────────────────────
log "Checking Anthropic API key..."
if grep -q "YOUR_ANTHROPIC_API_KEY" lib/services/chatbot_service.dart 2>/dev/null; then
    warn "Anthropic API key not set. Chatbot will not work."
    warn "Edit lib/services/chatbot_service.dart and replace YOUR_ANTHROPIC_API_KEY"
else
    ok "API key configured"
fi

# ── 4. Flutter pub get ───────────────────────────────────────────────────────
log "Fetching dependencies..."
flutter pub get
ok "Dependencies fetched"

# ── 5. Select target ─────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}Select build target:${NC}"
echo "  1) Run on connected device (debug)"
echo "  2) Build Android APK (release)"
echo "  3) Build Android App Bundle (Play Store)"
echo "  4) Build iOS (requires macOS + Xcode)"
echo "  5) Run on Android emulator"
echo "  6) Run on iOS simulator (macOS only)"
read -p "Choice [1-6]: " CHOICE

case $CHOICE in
  1)
    log "Running on connected device..."
    flutter run
    ;;
  2)
    log "Building Android APK..."
    flutter build apk --release --split-per-abi
    ok "APK built:"
    ls -lh build/app/outputs/flutter-apk/*.apk
    echo ""
    echo -e "${GREEN}Install on device:${NC}"
    echo "  adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
    ;;
  3)
    log "Building Android App Bundle..."
    flutter build appbundle --release
    ok "AAB built: build/app/outputs/bundle/release/app-release.aab"
    ;;
  4)
    log "Building iOS..."
    if [[ "$OSTYPE" != "darwin"* ]]; then
      err "iOS builds require macOS."
    fi
    cd ios && pod install && cd ..
    flutter build ios --release --no-codesign
    ok "iOS build complete. Open ios/Runner.xcworkspace in Xcode to archive."
    ;;
  5)
    log "Starting Android emulator..."
    flutter emulators --launch $(flutter emulators | grep -m1 "•" | awk '{print $1}') 2>/dev/null || true
    sleep 3
    flutter run
    ;;
  6)
    log "Launching iOS simulator..."
    open -a Simulator
    sleep 3
    flutter run
    ;;
  *)
    warn "Invalid choice. Running flutter run..."
    flutter run
    ;;
esac
